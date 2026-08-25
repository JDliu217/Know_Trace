-- =====================================================
-- 文件分类表（kb_file.tb_category）
-- 适用模块：kb-file（文件服务）
-- 对应实体：com.knowledge.base.file.entity.Category
-- 对应 Python：apps/file/models.py::FileCategory
--
-- 说明：该表在原有建表脚本中缺失，导致 Java CategoryController /
--       Python FileCategoryService 均无法工作。此脚本幂等创建该表。
--       Python 后端在启动时也会自动执行等价 DDL，二者任选其一即可。
-- =====================================================

SET NAMES utf8mb4;
USE `kb_file`;

CREATE TABLE IF NOT EXISTS `tb_category` (
  `id` BIGINT NOT NULL COMMENT '分类ID',
  `name` VARCHAR(100) NOT NULL COMMENT '分类名称',
  `parent_id` BIGINT NOT NULL DEFAULT 0 COMMENT '父分类ID，0=顶级分类',
  `level` INT NOT NULL DEFAULT 1 COMMENT '分类层级',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序序号',
  `icon` VARCHAR(255) DEFAULT NULL COMMENT '分类图标',
  `description` VARCHAR(500) DEFAULT NULL COMMENT '分类描述',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：0=禁用，1=启用',
  `deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0=正常，1=已删除',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `create_by` BIGINT DEFAULT NULL COMMENT '创建人ID',
  `update_by` BIGINT DEFAULT NULL COMMENT '更新人ID',
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_deleted` (`deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文件分类';
