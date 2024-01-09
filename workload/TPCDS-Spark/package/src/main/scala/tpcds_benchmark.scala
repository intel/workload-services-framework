import org.apache.spark.SparkContext
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.functions.{ getClass=> sqlGetClass}
import org.apache.commons.io.IOUtils
import com.databricks.spark.sql.perf.tpcds._
import com.databricks.spark.sql.perf.Query
import com.databricks.spark.sql.perf.ExecutionMode.CollectResults
import scala.util.Try

object TpcdsSparkBenchmark {

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
    println("Starting TPC-DS query execution")
    val databaseName: String = "tpcds_sf" + scaleFactor
    val databaseDir: String = rootDir + databaseName
    val resultsDir: String  = rootDir + "results"
    val format: String = "parquet" // valid spark format like parquet "parquet".

    val tables = new TPCDSTables(spark.sqlContext,
        dsdgenDir = "/tmp/tpcds-kit/tools", // location of dsdgen
        scaleFactor = scaleFactor,
        useDoubleForDecimal = false, // true to replace DecimalType with DoubleType
        useStringForDate = false) // true to replace DateType with StringType

    tables.createExternalTables(databaseDir, "parquet", databaseName, overwrite = true, discoverPartitions = true)

    // Run TPC-DS
    val tpcds = new TPCDS(sqlContext = spark.sqlContext)
    val queries = tpcds.tpcds2_4Queries
    val t0 = System.currentTimeMillis

    spark.sql(s"use $databaseName")

    val experiment = tpcds.runExperiment(
      queries,
      iterations = 1,
      resultLocation = resultsDir,
      forkThread = true)
    println(s"Running benchmark with scale factor: $scaleFactor")
    experiment.waitForFinish(24 * 60 * 60) // 24 hours
    val t1 = System.currentTimeMillis

    // Print results
    val diff = t1 - t0
    val minutes = diff / 60000
    val left = diff - (minutes * 60000)
    val seconds = left / 1000
    val miliseconds = left - (seconds * 1000)

    println("Test execution time: " + (t1 - t0) / 60000.0 + " (min)")
    println(minutes + "min " + seconds + "s " + miliseconds + "ms")

    println("Print results:")
    val summary = experiment.getCurrentResults
      .withColumn("Name", substring(col("name"), 2, 100))
      .withColumn("Runtime", (col("parsingTime") + col("analysisTime") + col("optimizationTime") + col("planningTime") + col("executionTime")) / 1000.0)
      .select("Name", "Runtime")
    summary.show(9999, false)
    println(s"Data saved to ${experiment.resultPath}\n")
    spark.stop()
  }
}
