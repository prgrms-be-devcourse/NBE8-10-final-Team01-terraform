# ============================================================
# AWS ElastiCache Redis
# ============================================================

# ElastiCache 서브넷 그룹
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name    = "${var.project_name}-cache-subnet-group"
    Project = var.project_name
  }
}

# ElastiCache Redis 클러스터 (단일 노드)
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  tags = {
    Name    = "${var.project_name}-redis"
    Project = var.project_name
  }
}
