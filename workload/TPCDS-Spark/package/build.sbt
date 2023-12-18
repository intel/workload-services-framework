version := "1.2"
scalaVersion := "2.12.10"
name := "tpcds-spark-benchmark"
libraryDependencies ++= Seq(
    "org.apache.spark" %% "spark-sql" % "3.2.2"
)