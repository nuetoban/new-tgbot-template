#!/usr/bin/env bash

# TODO: add helm chart

PYTHON="python3.10"

# Check args
print_help() {
    echo "Usage: new-bot BOT_NAME"
    exit 2
}

if [ -z "$1" ]; then
    print_help
fi

set -xe

mkdir "$1"
cd "$1"

# Python code
cat > main.py <<EOF
import logging
import os

from aiogram import Bot, Dispatcher, types, executor
from aiogram.contrib.middlewares.logging import LoggingMiddleware
from aiogram.dispatcher.webhook import DeleteMessage
from aiogram.utils.executor import start_webhook
from dotenv import load_dotenv

# Set up logging
logging.basicConfig(
    format="%(asctime)s %(levelname)-8s [%(filename)s:%(lineno)d] %(funcName)s: %(message)s",
    datefmt="%H:%M:%S",
    level=logging.INFO,
)

# Load env variables from .env file
load_dotenv()

# Telegram-related variables
API_TOKEN = os.getenv("BOT_TOKEN")
WEBHOOK_HOST = os.getenv("BOT_WEBHOOK_HOST")
WEBHOOK_PATH = os.getenv("BOT_WEBHOOK_PATH")
WEBHOOK_URL = f"{WEBHOOK_HOST}{WEBHOOK_PATH}"

if WEBHOOK_HOST:
    WEBHOOK_ENABLED = True
else:
    WEBHOOK_ENABLED = False

# Initialize bot
bot = Bot(token=API_TOKEN)
dp = Dispatcher(bot)
dp.middleware.setup(LoggingMiddleware())


async def __some_filter(message: types.Message) -> bool:
    return True


@dp.message_handler(__some_filter, content_types=types.ContentType.all())
async def handler(message: types.Message):
    """Deletes incoming messages"""
    if WEBHOOK_ENABLED:
        return DeleteMessage(message.chat.id, message.message_id)
    else:
        await message.delete()


@dp.message_handler(commands=["help", "start"])
async def help_handler(message: types.Message):
    """Answers to command /help"""
    pass


async def on_startup(_):
    await bot.set_webhook(WEBHOOK_URL)


if __name__ == "__main__":
    if WEBHOOK_ENABLED:
        start_webhook(
            dispatcher=dp,
            webhook_path=WEBHOOK_PATH,
            on_startup=on_startup,
            skip_updates=True,
            host="0.0.0.0",
            port=3001,
        )
    else:
        executor.start_polling(dp, skip_updates=True)
EOF

# requirements.txt
cat > requirements.txt <<EOF
python-dotenv==0.19.0
aiogram==2.17.1
EOF

# Dockerfile
cat > Dockerfile <<EOF
FROM python:3.10.0rc2-buster

ENV PYTHONUNBUFFERED 1

COPY requirements.txt .
RUN pip3 install -r requirements.txt && rm requirements.txt

COPY main.py .

CMD python3 main.py
EOF

# .env
cat > .env.example <<EOF
BOT_TOKEN=123456:abcdef
EOF

cp .env.example .env

# git
cat > .gitignore <<EOF
.vscode
.idea

venv

**/__pycache__
**/.pytest_cache
**/.env
**/.mypy_cache
**/.ipynb_checkpoints
**/.DS_Store
EOF
git init

# tag.txt
echo "0.1.0" > tag.txt

# Makefile
cat > Makefile <<'EOF'
DOCKER_REPO := example
DOCKER_TAG := $(shell cat tag.txt)

.PHONY: docker/build
docker/build:
	docker build --build-arg BOT_TAG="$(DOCKER_TAG)" -t "$(DOCKER_REPO):$(DOCKER_TAG)" .

.PHONY: docker/push
docker/push:
	docker push "$(DOCKER_REPO):$(DOCKER_TAG)"

.PHONY: test
test:
	cd tests && \
		pytest -v .

.PHONY: format
format:
	black -l 120 . --target-version py310

.PHONY: mypy
mypy:
	mypy --ignore-missing-imports . --exclude venv

.PHONY: run
run/py: format
	$(MAKE) format
	$(MAKE) mypy
	. venv/bin/activate; \
		python3 main.py
EOF

# venv
"$PYTHON" -m venv venv
. venv/bin/activate
pip3 install -r requirements.txt
pip3 install mypy black pytest

# tests
mkdir tests
