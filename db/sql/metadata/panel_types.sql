-- MySQL dump 10.13  Distrib 8.0.43, for Linux (x86_64)
--
-- Host: 127.0.0.1    Database: catalog
-- ------------------------------------------------------
-- Server version	8.0.43-0ubuntu0.24.04.1

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
-- Table structure for table `panel_types`
--

DROP TABLE IF EXISTS `panel_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `panel_types` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `moh_code` varchar(255) DEFAULT NULL,
  `nlims_code` varchar(255) DEFAULT NULL,
  `loinc_code` varchar(255) DEFAULT NULL,
  `preferred_name` varchar(255) DEFAULT NULL,
  `scientific_name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_panel_types_on_moh_code` (`moh_code`),
  UNIQUE KEY `index_panel_types_on_nlims_code` (`nlims_code`),
  UNIQUE KEY `index_panel_types_on_loinc_code` (`loinc_code`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `panel_types`
--

LOCK TABLES `panel_types` WRITE;
/*!40000 ALTER TABLE `panel_types` DISABLE KEYS */;
INSERT INTO `panel_types` VALUES (1,'CSF Analysis','CSF','2021-08-10 22:43:53','2021-08-10 22:43:53',NULL,'NLIMS_TP_0001_MWI',NULL,'CSF Analysis',NULL,NULL),(2,'Urine analysis','Urinalysis','2021-08-10 22:44:05','2025-08-06 16:12:48',NULL,'NLIMS_TP_0002_MWI',NULL,'Urinalysis','Urine analysis','<p>  To detect, isolate and identify organisms of pathological importance that cause infection along the urinary tract</p>'),(3,'Sterile Fluid Full Analysis','StFL','2021-08-10 22:44:16','2025-08-07 08:13:01',NULL,'NLIMS_TP_0003_MWI',NULL,'Sterile Fluid Analysis','Sterile Fluid Full Analysis','<p>  To aid in the diagnosis of inflammatory, infectious and neoplastic diseases involving body fluids.</p>'),(7,'Thyroid Function Tests','TFT','2025-04-19 21:55:31','2025-04-19 21:55:31',NULL,'NLIMS_TP_0007_MWI',NULL,'Thyroid Function Tests',NULL,NULL),(9,'Cryptococcal Test Panel','CrAg','2025-04-19 21:55:32','2025-08-07 08:26:28',NULL,'NLIMS_TP_0009_MWI',NULL,'CrAg Test Panel','Cryptococcal Test','<p>To screen for and diagnose cryptococcal meningitis in people with advanced HIV disease</p>'),(10,'Stool Culture','Stol MCS','2025-04-19 21:55:32','2025-04-19 21:55:32',NULL,'NLIMS_TP_0010_MWI',NULL,'Stool Culture',NULL,NULL),(11,'Coagulation Factors','Coagulation Factors','2025-08-07 13:57:14','2025-08-07 13:57:14',NULL,'NLIMS_TP_0011_MWI',NULL,'Coagulation Assay','Coagulation Factors','<p>To detect coagulation disorders</p>'),(12,'Coagulation Factor 50/50 Mixing Studies','Coagulation Factor 50/50 Mixing Studies','2025-08-07 14:00:34','2025-08-07 14:00:34',NULL,'NLIMS_TP_0012_MWI',NULL,'50/50 Mixing Studies ','Coagulation Factor 50/50 Mixing Studies','<p>To evaluate the mixing properties of an individual\'s blood components related to coagulation factors.&nbsp;Typically performed on patients with abnormal coagulation test results</p>'),(13,'Diabetes Panel','Diabetes Panel','2025-08-08 08:53:39','2025-08-08 08:53:39',NULL,'NLIMS_TP_0013_MWI',NULL,'Diabetes Panel','Diabetes Panel','<p>To diagnose and monitor diabetes&nbsp;</p>'),(14,'BioMarkers','BioMarkers','2025-08-13 11:57:01','2025-08-13 11:57:01',NULL,'NLIMS_TP_0014_MWI',NULL,'BioMarkers','BioMarkers','<p><br></p>');
/*!40000 ALTER TABLE `panel_types` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-10-31  9:23:30
