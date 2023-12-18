import org.apache.spark.SparkContext
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.functions.{ getClass=> sqlGetClass}
import org.apache.commons.io.IOUtils
import com.databricks.spark.sql.perf.tpcds._
import com.databricks.spark.sql.perf.Query
import com.databricks.spark.sql.perf.ExecutionMode.CollectResults
import scala.util.Try

object TpcdsSparkDatagen {

  def main(args: Array[String]) {
    val spark = SparkSession.builder().getOrCreate()
    val sc = spark.sparkContext

    // Get configration
    println("Spark config:")
    println(spark.conf.getAll)

    val scaleFactor: String = Try(args(0).toString).getOrElse("1")
    val rootDir: String = Try(args(1).toString).getOrElse("hdfs://master-0:9000/")
    val verboseLogging: Boolean = Try(args(2).toBoolean).getOrElse(false)

    println("TPC-DS benchmark config:")
    println(s" - Scale Factor  ${scaleFactor}")
    println(s" - Data Location ${rootDir}")

    if (verboseLogging) {
      sc.setLogLevel("INFO")
    }
    else {
      sc.setLogLevel("ERROR")
    }

    // Create query pool
    println("Starting TPC-DS data generation")
    val databaseName: String = "tpcds_sf" + scaleFactor
    val databaseDir: String = rootDir + databaseName
    val resultsDir: String  = rootDir + "results"
    val format: String = "parquet" // valid spark format like parquet "parquet".

    // Compress with snappy:
    spark.sqlContext.setConf("spark.sql.parquet.compression.codec", "snappy")
    // TPCDS has around 2000 dates.
    spark.conf.set("spark.sql.shuffle.partitions", "2000")
    // Don't write too huge files.
    spark.sqlContext.setConf("spark.sql.files.maxRecordsPerFile", "20000000")

    val dsdgenPartitioned=1000
    val dsdgenNonPartitioned=10 // small tables do not need much parallelism in generation.
    // If true, rows with nulls in partition key will be thrown away.
    val filterNull = false
    // If true, partitions will be coalesced into a single file during generation.
    val shuffle = true

    val t0 = System.currentTimeMillis

    val tables = new TPCDSTables(spark.sqlContext,
        dsdgenDir = "/tmp/tpcds-kit/tools", // location of dsdgen
        scaleFactor = scaleFactor,
        useDoubleForDecimal = false, // true to replace DecimalType with DoubleType
        useStringForDate = false) // true to replace DateType with StringType

    // generate all the small dimension tables
    val nonPartitionedTables = Array("call_center", "catalog_page", "customer", "customer_address", "customer_demographics", "date_dim", "household_demographics", "income_band", "item", "promotion", "reason", "ship_mode", "store",  "time_dim", "warehouse", "web_page", "web_site")
    nonPartitionedTables.foreach { t => {
      tables.genData(
          location = databaseDir,
          format = format,
          overwrite = true,
          partitionTables = true,
          clusterByPartitionColumns = shuffle,
          filterOutNullPartitionValues = filterNull,
          tableFilter = t,
          numPartitions = dsdgenNonPartitioned)
    }}
    println("Done generating non partitioned tables.")

    // leave the biggest/potentially hardest tables to be generated last.
    val partitionedTables = Array("inventory", "web_returns", "catalog_returns", "store_returns", "web_sales", "catalog_sales", "store_sales")
    partitionedTables.foreach { t => {
      tables.genData(
         location = databaseDir,
         format = format,
         overwrite = true,
         partitionTables = true,
         clusterByPartitionColumns = shuffle,
         filterOutNullPartitionValues = filterNull,
         tableFilter = t,
         numPartitions = dsdgenPartitioned)
   }}
   println("Done generating partitioned tables.")

    val t1 = System.currentTimeMillis
    val diff = t1 - t0
    val minutes = diff / 60000
    val left = diff - (minutes * 60000)
    val seconds = left / 1000
    val miliseconds = left - (seconds * 1000)

    println("Data generation time: " + (t1 - t0) / 60000.0 + " (min)")
    println(minutes + "min " + seconds + "s " + miliseconds + "ms")

    spark.stop()
  }
}
