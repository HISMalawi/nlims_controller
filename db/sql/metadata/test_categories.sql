-- MySQL dump 10.13  Distrib 8.0.44, for Linux (x86_64)
--
-- Host: 127.0.0.1    Database: catalog
-- ------------------------------------------------------
-- Server version	8.0.44-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `test_categories`
--

DROP TABLE IF EXISTS `test_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `test_categories` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  `moh_code` varchar(255) DEFAULT NULL,
  `nlims_code` varchar(255) DEFAULT NULL,
  `loinc_code` varchar(255) DEFAULT NULL,
  `preferred_name` varchar(255) DEFAULT NULL,
  `scientific_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_test_categories_on_moh_code` (`moh_code`),
  UNIQUE KEY `index_test_categories_on_nlims_code` (`nlims_code`),
  UNIQUE KEY `index_test_categories_on_loinc_code` (`loinc_code`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_categories`
--

LOCK TABLES `test_categories` WRITE;
/*!40000 ALTER TABLE `test_categories` DISABLE KEYS */;
INSERT INTO `test_categories` VALUES (1,'Microbiology','','2021-12-09 04:07:33','2025-08-14 11:34:32','Microbiology',NULL,'NLIMS_TC_0001_MWI',NULL,'Microbiology','Microbiology'),(2,'Haematology','','2021-12-09 04:07:51','2025-08-14 11:34:46','Haematology',NULL,'NLIMS_TC_0002_MWI',NULL,'Haematology','Haematology'),(3,'Blood Bank','','2021-12-09 04:08:12','2025-08-14 11:34:56','Blood Bank',NULL,'NLIMS_TC_0003_MWI',NULL,'Blood Bank','Blood Bank'),(4,'Serology','','2021-12-09 04:08:25','2025-08-14 11:35:05','Serology',NULL,'NLIMS_TC_0004_MWI',NULL,'Serology','Serology'),(5,'Lab Reception','','2021-12-09 04:08:37','2025-08-14 11:35:17','Lab Reception',NULL,'NLIMS_TC_0005_MWI',NULL,'Lab Reception','Lab Reception'),(6,'Biochemistry','','2021-12-09 04:08:46','2025-08-14 11:35:32','Biochemistry',NULL,'NLIMS_TC_0006_MWI',NULL,'Biochemistry','Biochemistry'),(7,'FLow Cytometry','','2021-12-09 04:08:55','2025-08-14 11:35:42','FLow Cytometry',NULL,'NLIMS_TC_0007_MWI',NULL,'FLow Cytometry','FLow Cytometry'),(8,'DNA/PCR','','2021-12-09 04:09:07','2025-08-14 11:35:55','DNA/PCR',NULL,'NLIMS_TC_0008_MWI',NULL,'DNA/PCR','DNA/PCR'),(9,'Parasitology',NULL,'2024-07-18 19:21:12','2025-08-14 11:36:05','Parasitology',NULL,'NLIMS_TC_0009_MWI',NULL,'Parasitology','Parasitology'),(10,'Histopathology',NULL,'2024-07-18 19:21:13','2025-08-14 11:36:20','Histopathology',NULL,'NLIMS_TC_0010_MWI',NULL,'Histopathology','Histopathology'),(11,'Molecular Biology',NULL,'2024-07-18 19:21:13','2025-08-11 16:28:20','Molecular Biology',NULL,NULL,NULL,'Molecular Biology','Molecular Biology'),(12,'Toxicology','','2025-08-11 08:08:38','2025-08-11 08:08:38','Toxicology',NULL,'NLIMS_TC_0012_MWI',NULL,'Toxicology','Toxicology'),(13,'Virology','','2025-08-11 16:30:18','2025-08-11 16:30:18','Virology',NULL,'NLIMS_TC_0013_MWI',NULL,'Virology','Virology');
/*!40000 ALTER TABLE `test_categories` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-12-11 14:22:22
