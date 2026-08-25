# TADB 202620 - Examen 01

## Cadena de frío de medicamentos - Distri-Cold

Proyecto desarrollado para el curso de Topicos Avanzados de Base de Datos

---

## Información del proyecto

**Periodo:** 202620  
**Examen:** No. 1  
**Dominio:** Cadena de frío de medicamentos  
**Motor de base de datos:** PostgreSQL 18  
**Infraestructura:** Docker Desktop  
**IDE:** DBeaver  

---

## Estudiante

David Vergara Arredondo
000287497

---

## Descripción

El proyecto implementa una base de datos relacional para gestionar información relacionada con la cadena de frío de medicamentos de la empresa Distri-Cold.

La solución permite centralizar información de fabricantes, medicamentos, lotes, almacenes, existencias de inventario y lecturas de temperatura.

El modelo fue diseñado aplicando un proceso de normalización hasta **Tercera Forma Normal (3NF)**.

---

## Modelo de datos

El modelo está compuesto por las siguientes tablas:

- `fabricante`
- `medicamento`
- `almacen`
- `lote`
- `existencia_inventario`
- `lectura_temperatura`

# Estrucutra del repositorio:

tadb202620_examen_01/
│
├── docs/
│   ├── 01 - Infraestructura y conexión.pdf
│   ├── 02 - Interacción con IA.pdf
│   └── diagrama_relacional.png
│
├── sql/
│   ├── implementacion.sql
│   ├── carga_datos.sql
│   ├── consultas.sql
│   └── funciones.sql
│
├── resultados/
│   ├── consulta_a.csv
│   ├── consulta_b.csv
│   ├── consulta_c.csv
│   └── etapa5_saltosTermicos.csv
│
├── data/
│
├── .gitignore
└── README.md
