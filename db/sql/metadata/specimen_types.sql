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
-- Table structure for table `specimen_types`
--

DROP TABLE IF EXISTS `specimen_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `specimen_types` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` text CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `moh_code` varchar(255) DEFAULT NULL,
  `nlims_code` varchar(255) DEFAULT NULL,
  `loinc_code` varchar(255) DEFAULT NULL,
  `preferred_name` varchar(255) DEFAULT NULL,
  `scientific_name` varchar(255) DEFAULT NULL,
  `iblis_mapping_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_specimen_types_on_moh_code` (`moh_code`),
  UNIQUE KEY `index_specimen_types_on_nlims_code` (`nlims_code`),
  UNIQUE KEY `index_specimen_types_on_loinc_code` (`loinc_code`)
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `specimen_types`
--

LOCK TABLES `specimen_types` WRITE;
/*!40000 ALTER TABLE `specimen_types` DISABLE KEYS */;
INSERT INTO `specimen_types` VALUES (1,'Sputum','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0001_MWI',NULL,'Sputum',NULL,'Sputum'),(2,'Cerebrospinal Fluid','','2021-04-14 14:13:47','2025-08-14 11:09:27',NULL,'NLIMS_SP_0002_MWI',NULL,'CSF','Cerebrospinal Fluid','CSF'),(3,'Venous Whole Blood','<p>Deoxygenated blood which travels from the peripheral blood vessels, through the venous system into the right atrium of the heart.</p>','2021-04-14 14:13:47','2025-04-19 22:14:58',NULL,'NLIMS_SP_0003_MWI',NULL,'Blood','Venous Whole Blood','Blood'),(4,'Pleural Fluid','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0004_MWI',NULL,'Pleural Fluid',NULL,'Pleural Fluid'),(5,'Ascitic Fluid','','2021-04-14 14:13:47','2025-08-14 11:08:35',NULL,'NLIMS_SP_0005_MWI',NULL,'Ascitic Fluid','Ascitic Fluid','Ascitic Fluid'),(6,'Pericardial Fluid','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0006_MWI',NULL,'Pericardial Fluid',NULL,'Pericardial Fluid'),(7,'Peritoneal Fluid','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0007_MWI',NULL,'Peritoneal Fluid',NULL,'Peritoneal Fluid'),(8,'HVS','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0008_MWI',NULL,'HVS',NULL,'HVS'),(9,'Swabs','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0009_MWI',NULL,'Swabs',NULL,'Swabs'),(10,'Pus','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0010_MWI',NULL,'Pus',NULL,'Pus'),(11,'Stool','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0011_MWI',NULL,'Stool',NULL,'Stool'),(12,'Urine','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0012_MWI',NULL,'Urine',NULL,'Urine'),(13,'Other','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0013_MWI',NULL,'Other',NULL,'Other'),(14,'Semen','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0014_MWI',NULL,'Semen',NULL,'Semen'),(16,'Synovial Fluid','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0016_MWI',NULL,'Synovial Fluid',NULL,'Synovial Fluid'),(17,'Plasma','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0017_MWI',NULL,'Plasma',NULL,'Plasma'),(18,'DBS (Free drop to DBS card)','','2021-04-14 14:13:47','2025-08-14 11:10:18',NULL,'NLIMS_SP_0018_MWI',NULL,'DBS (Free drop to DBS card)','DBS (Free drop to DBS card)','DBS (Free drop to DBS card)'),(19,'DBS (Using capillary tube)','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0019_MWI',NULL,'DBS (Using capillary tube)',NULL,'DBS (Using capillary tube)'),(20,'Serum','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0020_MWI',NULL,'Serum',NULL,'Serum'),(22,'Gastric aspirate','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0022_MWI',NULL,'Gastric aspirate',NULL,'Gastric aspirate'),(23,'Nasopharyngeal swab','','2021-04-14 14:13:47','2021-04-14 14:13:47',NULL,'NLIMS_SP_0023_MWI',NULL,'Nasopharyngeal swab',NULL,'Nasopharyngeal swab'),(24,'Fine Needle Aspiration (FNA)','','2021-04-21 09:58:52','2025-08-10 11:49:56',NULL,'NLIMS_SP_0024_MWI',NULL,'Fine Needle Aspiration (FNA)','Fine Needle Aspiration (FNA)','FNA'),(25,'Fluid Aspirate','','2021-05-01 14:32:07','2025-08-14 11:09:52',NULL,'NLIMS_SP_0025_MWI',NULL,'Fluid Aspirate','Fluid Aspirate','Fluid Aspirate'),(26,'Aspirate','','2021-05-04 05:31:31','2025-08-14 11:08:46',NULL,'NLIMS_SP_0026_MWI',NULL,'Aspirate','Aspirate','Aspirate'),(27,'Tissue','','2021-05-04 07:26:50','2025-08-14 11:08:24',NULL,'NLIMS_SP_0027_MWI',NULL,'Tissue','Tissue','Tissue'),(28,'not_specified','','2021-06-14 11:12:59','2021-06-14 11:12:59',NULL,'NLIMS_SP_0028_MWI',NULL,NULL,NULL,NULL),(30,'Oralpharyngeal','','2021-06-18 12:23:06','2025-08-14 11:07:55',NULL,'NLIMS_SP_0030_MWI',NULL,'Oralpharyngeal','Oralpharyngeal','Oralpharyngeal'),(31,'DBS 70ml','','2021-09-28 11:47:05','2021-09-28 11:47:05',NULL,'NLIMS_SP_0031_MWI',NULL,'DBS 70ml',NULL,'DBS 70ml'),(38,'Tissue Biopsies',NULL,'2025-04-19 21:51:10','2025-08-14 11:08:14',NULL,'NLIMS_SP_0038_MWI',NULL,'Tissue Biopsies','Tissue Biopsies','Tissue Biopsies'),(39,'VP Shunt Tip',NULL,'2025-04-19 21:51:10','2025-08-14 11:10:37',NULL,'NLIMS_SP_0039_MWI',NULL,'VP Shunt Tip','VP Shunt Tip','VP Shunt Tip'),(40,'DBS','','2025-04-19 21:55:19','2025-08-14 11:09:38',NULL,'NLIMS_SP_0040_MWI',NULL,'DBS','DBS','DBS'),(42,'Dialysis Water','','2025-04-19 21:55:19','2025-04-19 21:55:19',NULL,'NLIMS_SP_0042_MWI',NULL,'Dialysis Water',NULL,'Dialysis Water'),(43,'Nosal swab','','2025-04-19 21:55:19','2025-04-19 21:55:19',NULL,'NLIMS_SP_0043_MWI',NULL,'Nosal swab',NULL,'Nosal swab'),(44,'Rectal Swab','','2025-04-19 21:55:19','2025-04-19 21:55:19',NULL,'NLIMS_SP_0044_MWI',NULL,'Rectal Swab',NULL,'Rectal Swab'),(45,'Capillary Whole Blood','<p>Usually obtained by fingerstick, heelstick (commonly used for infants), or from an earlobe</p>','2025-04-19 22:17:38','2025-04-19 22:17:38',NULL,'NLIMS_SP_0045_MWI',NULL,'Capillary Whole Blood','Capillary Whole Blood','Capillary Whole Blood'),(47,'Oral Fluid','<p>the liquid present in the oral cavity</p>','2025-04-29 10:38:48','2025-04-29 10:38:48',NULL,'NLIMS_SP_0047_MWI',NULL,'Oral Fluid','Oral Fluid','Oral Fluid'),(48,'Cervical Cells','','2025-05-06 10:31:17','2025-05-06 10:31:17',NULL,'NLIMS_SP_0048_MWI',NULL,'Cervical Cells','Cervical Cells','Cervical Cells'),(49,'Bronchial Brushings','','2025-08-10 11:40:11','2025-08-10 11:40:11',NULL,'NLIMS_SP_0049_MWI',NULL,'Bronchial Brushings','Bronchial Brushings','Bronchial Brushings'),(50,'Bronchoalveolar Lavage','','2025-08-10 11:40:54','2025-08-10 11:40:54',NULL,'NLIMS_SP_0050_MWI',NULL,'BAL','Bronchoalveolar Lavage','Bronchoalveolar Lavage (BAL)'),(52,'Food','','2025-08-11 10:05:33','2025-08-11 10:05:33',NULL,'NLIMS_SP_0052_MWI',NULL,'Food','Food','Food'),(53,'Beverage','','2025-08-11 10:05:44','2025-08-11 10:05:44',NULL,'NLIMS_SP_0053_MWI',NULL,'Beverage','Beverage','Beverage'),(54,'Arterial Blood','','2025-08-11 10:31:12','2025-08-11 10:31:12',NULL,'NLIMS_SP_0054_MWI',NULL,'Arterial Blood','Arterial Blood','Arterial Blood'),(55,'Skin Lesion','','2025-08-11 11:26:04','2025-08-11 11:26:04',NULL,'NLIMS_SP_0055_MWI',NULL,'Skin Lesion','Skin Lesion','Skin Lesion'),(56,'Respiratory Secretion','','2025-08-11 11:26:25','2025-08-11 11:26:25',NULL,'NLIMS_SP_0056_MWI',NULL,'Respiratory Secretion','Respiratory Secretion','Respiratory Secretion'),(57,'Skin Scraps','','2025-08-11 15:40:31','2025-08-11 15:40:31',NULL,'NLIMS_SP_0057_MWI',NULL,'Skin Scraps','Skin Scraps','Skin Scraps');
/*!40000 ALTER TABLE `specimen_types` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-11-28  8:39:18
