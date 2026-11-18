#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Универсальный скрипт отправки почты для Project Guardian.
Поддерживает вложения, SSL/TLS, многострочный текст и HTML.
Конфигурация считывается из ~/.gemini/config/email_settings.json
"""

import os
import sys
import json
import argparse
import smtplib
import mimetypes
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from email.header import Header

# Гарантия UTF-8 в Windows-терминале
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

def load_config():
    config_path = Path.home() / ".gemini" / "config" / "email_settings.json"
    if not config_path.exists():
        raise FileNotFoundError(
            f"Файл настроек почты не найден: {config_path}\n"
            "Создайте его с полями: smtp_server, smtp_port, smtp_user, smtp_pass, default_recipient"
        )
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)

def send_email(subject, body, to_email=None, attachments=None, is_html=False):
    cfg = load_config()

    smtp_server = cfg.get("smtp_server", "smtp.mail.ru")
    smtp_port = int(cfg.get("smtp_port", 465))
    smtp_user = cfg.get("smtp_user")
    smtp_pass = cfg.get("smtp_pass")
    sender_name = cfg.get("sender_name", "Antigravity Assistant")
    recipient = to_email or cfg.get("default_recipient")

    if not recipient:
        raise ValueError("Не указан адрес получателя и отсутствует default_recipient в настройках")
    if not smtp_user or not smtp_pass:
        raise ValueError("В настройках email_settings.json отсутствуют smtp_user или smtp_pass")

    msg = MIMEMultipart()
    # RFC-совместимый заголовок From с кодировкой UTF-8 для имени
    msg['From'] = f"{Header(sender_name, 'utf-8').encode()} <{smtp_user}>"
    msg['To'] = recipient
    msg['Subject'] = Header(subject, 'utf-8').encode()

    # Добавление тела письма
    subtype = 'html' if is_html else 'plain'
    msg.attach(MIMEText(body, subtype, 'utf-8'))

    # Добавление вложений
    attached_files = []
    if attachments:
        for file_path_str in attachments:
            file_path = Path(file_path_str.strip('"\'')).resolve()
            if not file_path.exists():
                print(f"[ВНИМАНИЕ] Файл для вложения не найден: {file_path}", file=sys.stderr)
                continue

            ctype, encoding = mimetypes.guess_type(str(file_path))
            if ctype is None or encoding is not None:
                ctype = 'application/octet-stream'
            maintype, subtype = ctype.split('/', 1)

            with open(file_path, 'rb') as f:
                part = MIMEBase(maintype, subtype)
                part.set_payload(f.read())
            encoders.encode_base64(part)

            # Безопасное имя вложения для кириллицы
            filename = file_path.name
            part.add_header('Content-Disposition', 'attachment', filename=('utf-8', '', filename))
            msg.attach(part)
            attached_files.append(f"{filename} ({file_path.stat().st_size} bytes)")

    print(f"[Email] Подключение к {smtp_server}:{smtp_port} (SSL)...")
    with smtplib.SMTP_SSL(smtp_server, smtp_port, timeout=60) as server:
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)

    print(f"[OK] Письмо успешно отправлено!")
    print(f"  Кому:      {recipient}")
    print(f"  Тема:      {subject}")
    if attached_files:
        print(f"  Вложения ({len(attached_files)}): {', '.join(attached_files)}")
    return True

def main():
    parser = argparse.ArgumentParser(description="Отправка email через Project Guardian")
    parser.add_argument("--to", help="Email получателя (по умолчанию из настроек)", default=None)
    parser.add_argument("--subject", required=True, help="Тема письма")
    parser.add_argument("--body", required=True, help="Текст письма")
    parser.add_argument("--attach", nargs="*", help="Пути к прикрепляемым файлам", default=[])
    parser.add_argument("--html", action="store_true", help="Флаг: тело письма в формате HTML")

    args = parser.parse_args()

    try:
        send_email(
            subject=args.subject,
            body=args.body,
            to_email=args.to,
            attachments=args.attach,
            is_html=args.html
        )
        sys.exit(0)
    except Exception as e:
        print(f"[ОШИБКА] Не удалось отправить письмо: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
