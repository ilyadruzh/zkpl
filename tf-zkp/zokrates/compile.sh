#!/bin/bash

# ADM: Создание арифметической схемы программы создающей артефакты документа
zokrates compile -i src/prog1.zok -o build/org1/prog1

# ORG1: Создание нобходимых артефактов после -а передаются параметры bytes32
zokrates compute-witness -i build/org1/prog1 -o build/org1/witness -a 0 0 0 5

# ORG1: компиляция целевой программы проверяющая доказателтства
zokrates compile -i src/prog2.zok -o build/org1/prog2

# ORG1: запуск трастед сетуап и создание смарт-контракта
zokrates setup -i build/org1/prog2 # переместить ключи в build/org1/keys
zokrates export-verifier -i build/org1/keys/verification.key # переместить смарт-контракт в build/org1/sol

# ORG2: создает доказательство - создает артефакты
zokrates compute-witness -i build/org2/prog1 -o build/org2/witness -a 0 0 0 5
zokrates generate-proof # подкиниуть ключ

# ORG2: отправка транзакции с проверкой доказателя
