# ============================================================================
# Makefile for Inception Project
# ============================================================================
# This Makefile manages Docker containers using docker-compose
# It provides convenient commands for starting and stopping services
# ============================================================================

# ================================ VARIABLES ================================= #

NAME			= inception

COMPOSE_FILE	= srcs/docker-compose.yml

COMPOSE_CMD		= docker compose --file $(COMPOSE_FILE) --project-name $(NAME)

LOGIN = $(shell whoami)
# MacOS
DATA_DIR = /Users/$(LOGIN)/data
# # Linux
# DATA_DIR = /home/$(LOGIN)/data
WP_DATA_DIR = $(DATA_DIR)/wordpress
DB_DATA_DIR = $(DATA_DIR)/mariadb

export LOGIN
export DATA_DIR
export WP_DATA_DIR
export DB_DATA_DIR

GREEN		= \033[0;32m
YELLOW		= \033[0;33m
RED			= \033[0;31m
BLUE		= \033[0;34m
RESET		= \033[0m

# ================================= TARGETS ================================== #

# Default target
all: setup up
	@echo "$(GREEN)✓ Inception is running!$(RESET)"
	@echo "Access your website at: https://$(LOGIN).42.fr"

# Set up volume directories
setup:
	@echo "$(BLUE)Setting up data directories...$(RESET)"
	@mkdir -p $(WP_DATA_DIR)
	@mkdir -p $(DB_DATA_DIR)
	@echo "$(GREEN)✓ Data directories created$(RESET)"

# Start the container (in the background)
up: setup
	@echo "$(BLUE)Starting containers...$(RESET)"
	@$(COMPOSE_CMD) up --detach --build
	@echo "$(GREEN)✓ Containers started$(RESET)"
	@echo "Run 'make logs' to view container logs"

# Stop and remove containers
down:
	@echo "$(BLUE)Stopping and removing containers...$(RESET)"
	@$(COMPOSE_CMD) down
	@echo "$(GREEN)✓ Containers stopped$(RESET)"

# Display Logs
logs:
	@$(COMPOSE_CMD) logs --follow

# Check container status
status:
	@$(COMPOSE_CMD) ps

# Cleanup (remove containers, networks, and volumes)
clean: down
	@echo "$(BLUE)Cleaning up containers, networks, and volumes...$(RESET)"
	@$(COMPOSE_CMD) down -v
	@echo "$(GREEN)✓ Cleanup complete$(RESET)"

# Full cleanup (also remove image and data directories)
fclean: clean
	@echo "$(BLUE)Removing all images and data directories...$(RESET)"
	@$(COMPOSE_CMD) down --rmi all
	@sudo rm -rf $(WP_DATA_DIR)
	@sudo rm -rf $(DB_DATA_DIR)
	@echo "$(GREEN)✓ Full cleanup complete$(RESET)"

# Rebuild
re: fclean all
	@echo "$(GREEN)✓ Project rebuilt$(RESET)"

# ヘルプメッセージ
help:
	@echo "$(BLUE)Inception Makefile - Available commands:$(RESET)"
	@echo "  $(GREEN)make [all]$(RESET)      : Setup and start all containers"
	@echo "  $(GREEN)make up$(RESET)         : Start containers in background"
	@echo "  $(GREEN)make down$(RESET)       : Stop and remove containers"
	@echo "  $(GREEN)make logs$(RESET)       : Show container logs"
	@echo "  $(GREEN)make status$(RESET)     : Show container status"
	@echo "  $(GREEN)make clean$(RESET)      : Remove containers and volumes"
	@echo "  $(GREEN)make fclean$(RESET)     : Full cleanup (images + data)"
	@echo "  $(GREEN)make re$(RESET)         : Rebuild everything"
	@echo "  $(GREEN)make help$(RESET)       : Show this help message"

.PHONY: all setup up down logs status clean fclean re help
