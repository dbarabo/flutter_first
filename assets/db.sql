
/* 1. Валюты - DEF RUR */
create table CURRENCY (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(10) NOT NULL UNIQUE,
EXT varchar(3) NOT NULL UNIQUE,
SYNC INT
);

/* 2.  Счета */
create table ACCOUNT (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100) NOT NULL UNIQUE,
DESCRIPTION varchar(1024),
CURRENCY INT NOT NULL REFERENCES CURRENCY(ID),
TYPE INT NOT NULL DEFAULT 0, /* 0-текущие счета, 1-Кредиты, 2-Депозиты */
CLOSED DATE,
IS_USE_DEBT INT NOT NULL DEFAULT 0, /* 1-учитывать в долгах субъекта */
SYNC INT,
CHECK (TYPE in (0, 1, 2)),
CHECK (IS_USE_DEBT in (0, 1))
);

/* 3. */
create table CATEGORY (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100) NOT NULL,
PARENT INT,
TYPE INT NOT NULL DEFAULT 0, /*тип 0-расход 1-приход 2-перевод*/
SYNC INT,
CHECK (TYPE in (0, 1, 2))
);

/* 4. */
create table PERSON (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100) NOT NULL,
PARENT INT,
CONTACT varchar(100),
DESCRIPTION varchar(1024),
SYNC INT
);

/* 5. Проекты */
create table PROJECT (
ID INT NOT NULL CONSTRAINT PROJECT_PK PRIMARY KEY,
NAME varchar(100) NOT NULL,
PARENT INT /*REFERENCES PROJECT(ID)*/,
DESCRIPTION varchar(1024),
CREATED DATE NOT NULL DEFAULT CURRENT_DATE,
CLOSED DATE,
STATE INT NOT NULL DEFAULT 0, /*тип 0-только создан, 1-открыт 2-исполнен 3-отменен */
SYNC INT,
CHECK (STATE in (0, 1, 2, 3))
);

/* 6. платежи */
create table PAY (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100),
ACCOUNT INT NOT NULL REFERENCES ACCOUNT(ID),
CREATED DATE NOT NULL DEFAULT CURRENT_DATE,
AMOUNT NUMERIC(12, 2) NOT NULL, /*минус - расход + - приход*/
CATEGORY INT REFERENCES CATEGORY(ID), /* категория платежа */
ACCOUNT_TO INT REFERENCES ACCOUNT(ID), /* в случае перевода на др. счет */
AMOUNT_TO NUMERIC(12, 2), /* для разновалютных переводов иначе null */
DESCRIPTION varchar(1024),
PROJECT INT REFERENCES PROJECT(ID),
NUMBER_OF INT, /* кол-во*/
PERSON INT REFERENCES PERSON(ID),
SYNC INT
);

/* 7. Бюджет - весь */
create table BUDGET_MAIN (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(200),
TYPE_PERIOD INT NOT NULL DEFAULT 0, /*тип периода 0-месячн, 1-годовой, 2-квартальный, 3-полугодовой, 4-заданный по датам*/
START_PERIOD DATE NOT NULL,
END_PERIOD DATE NOT NULL,
SYNC INT
);

/* 8. Строка бюджета - содержит список категорий */
create table BUDGET_ROW (
ID INT NOT NULL PRIMARY KEY,
MAIN INT NOT NULL REFERENCES BUDGET_MAIN(ID),
NAME varchar(200),
AMOUNT NUMERIC(12, 2) NOT NULL DEFAULT 0, /*сумма строки бюджета*/
SYNC INT
);

/* 9. Категория строки бюджета */
create table BUDGET_CATEGORY (
ID INT NOT NULL PRIMARY KEY,
BUDGET_ROW INT NOT NULL REFERENCES BUDGET_ROW(ID),
CATEGORY INT NOT NULL REFERENCES CATEGORY(ID), /* категория входящ в строку бюджета */
INCLUDE_SUB_CATEGORY INT NOT NULL DEFAULT 0, /* включать все подкатегории тоже -значение 1*/
SYNC INT
);

/* 10. Планы */
create table PLAN (
ID INT NOT NULL PRIMARY KEY,
NAME varchar(100),
STARTED DATE NOT NULL,
ENDED DATE NOT NULL,
CATEGORY INT REFERENCES CATEGORY(ID), /*кто-то 1 категория или проект */
PROJECT INT REFERENCES PROJECT(ID),
AMOUNT NUMERIC(12, 2) NOT NULL,
NUMBER_OF INT,
SYNC INT
);

/* 11. Профиль */
create table PROFILE (
ID INT NOT NULL PRIMARY KEY,
MAIL varchar(100),
PSWD_HASH varchar(100),
SYNC_TYPE INT NOT NULL DEFAULT 0,
MSG_UID_SYNC INT /*последний загруженый/отправленный месседж*/
)