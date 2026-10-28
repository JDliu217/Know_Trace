-- =====================================================
-- 修复 ai_feedback 表结构，使其与实体类匹配
-- 缺失字段: user_id, feedback_content, rating
-- =====================================================

SET NAMES utf8mb4;
USE `kb_ai`;
SET FOREIGN_KEY_CHECKS = 0;

ALTER TABLE `ai_feedback`
  ADD COLUMN `user_id` BIGINT NOT NULL COMMENT '用户ID' AFTER `message_id`,
  ADD COLUMN `feedback_content` TEXT COMMENT '反馈内容' AFTER `feedback_type`,
  ADD COLUMN `rating` INT COMMENT '评分（1-5分）' AFTER `feedback_content`;

ALTER TABLE `ai_feedback`
  ADD INDEX `idx_user_id` (`user_id`);

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'ai_feedback 表结构修复完成！' AS message;
