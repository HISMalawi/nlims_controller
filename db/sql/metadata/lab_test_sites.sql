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
-- Table structure for table `lab_test_sites`
--

DROP TABLE IF EXISTS `lab_test_sites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lab_test_sites` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `description` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_test_sites`
--

LOCK TABLES `lab_test_sites` WRITE;
/*!40000 ALTER TABLE `lab_test_sites` DISABLE KEYS */;
INSERT INTO `lab_test_sites` VALUES (1,'Community Setting','A setting where health services are provided in the community, often with limited diagnostic capabilities.','2025-04-19 21:51:05.000000','2025-04-19 21:51:05.000000'),(2,'Primary health facilities without laboratories','Basic health facilities that provide primary care but do not have laboratory services for diagnostic testing.','2025-04-19 21:51:05.000000','2025-04-19 21:51:05.000000'),(3,'Primary health facilities with clinical laboratories (including urban health centres)','Primary care health facilities equipped with clinical laboratories, including urban health centres that provide diagnostic testing services.','2025-04-19 21:51:06.000000','2025-04-19 21:51:06.000000'),(4,'Secondary level health facilities (including community hospitals)','Health facilities providing specialized care and diagnostic services, including community hospitals offering more advanced medical services.','2025-04-19 21:51:06.000000','2025-04-19 21:51:06.000000'),(5,'Tertiary level health facilities','Advanced healthcare facilities offering specialized treatment, surgeries, and diagnostic testing, typically located in larger urban areas.','2025-04-19 21:51:06.000000','2025-04-19 21:51:06.000000'),(6,'National public health reference laboratory','A national laboratory focused on public health surveillance, providing reference testing and supporting national health programs.','2025-04-19 21:51:06.000000','2025-04-19 21:51:06.000000');
/*!40000 ALTER TABLE `lab_test_sites` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-12-11 14:22:21
