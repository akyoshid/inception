NAME			= inception

COMPOSE_FILE	= srcs/docker-compose.yml

COMPOSE_CMD		= docker compose --file $(COMPOSE_FILE) --project-name $(NAME)

all: up

up:

down:

clean:

fclean: clean

re: fclean all

.PHONY: all up down clean fclean re

