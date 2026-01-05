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
-- Table structure for table `measure_types`
--

DROP TABLE IF EXISTS `measure_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `measure_types` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `structure` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `measure_types`
--

LOCK TABLES `measure_types` WRITE;
/*!40000 ALTER TABLE `measure_types` DISABLE KEYS */;
INSERT INTO `measure_types` VALUES (1,'Numeric','2025-04-19 21:51:04','2025-04-19 21:55:19','A numeric measurement type','{\"type\": \"ranges\", \"parameters\": [{\"name\": \"Age Range\", \"type\": \"range\", \"values\": [{\"min\": \"number\"}, {\"max\": \"number\"}]}, {\"name\": \"Measure Range\", \"type\": \"range\", \"values\": [{\"min\": \"number\"}, {\"max\": \"number\"}]}, {\"name\": \"Interpretation\", \"type\": \"string\", \"values\": \"interpretation\"}, {\"name\": \"Sex\", \"type\": \"options\", \"values\": [\"Male\", \"Female\", \"Both\"]}]}'),(2,'Free Text','2025-04-19 21:51:04','2025-04-19 21:55:19','A freely entered text value','{\"type\": \"free_text\"}'),(3,'AlphaNumeric','2025-04-19 21:51:04','2025-04-19 21:55:19','A combination of letters and numbers','{\"type\": \"options\", \"parameters\": [{\"name\": \"value\", \"type\": \"string\", \"values\": \"value\"}, {\"name\": \"Interpretation\", \"type\": \"string\", \"values\": \"interpretation\"}]}'),(4,'Rich Text','2025-04-19 21:51:04','2025-04-19 21:55:19','Formatted text with styling options','{\"type\": \"rich_text\"}'),(5,'AutoComplete','2025-04-19 21:55:19','2025-04-19 21:55:19','A combination of letters and numbers','{\"type\": \"options\", \"parameters\": [{\"name\": \"value\", \"type\": \"string\", \"values\": \"value\"}, {\"name\": \"Interpretation\", \"type\": \"string\", \"values\": \"interpretation\"}]}');
/*!40000 ALTER TABLE `measure_types` ENABLE KEYS */;
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
