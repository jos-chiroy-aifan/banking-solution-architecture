# BP - Digital Banking Solution Architecture (SADD)

Este repositorio contiene el **Documento de Diseño de Arquitectura de Solución (SADD)** y los artefactos técnicos asociados para la plataforma multicanal de banca digital de la entidad **BP**.

La solución propone una arquitectura desacoplada, segura, altamente disponible y orientada a servicios, diseñada bajo el modelo **C4**, principios de arquitectura empresarial, patrones de integración modernos y estándares relevantes para sistemas financieros.

---

## 👤 Autoría y uso de IA

* **Arquitecto de Soluciones:** José Enmanuel Chiroy Aifán.
* **Responsabilidad técnica:** La definición arquitectónica, selección de patrones, análisis de riesgos, decisiones arquitectónicas (ADRs) y criterios de diseño fueron estructurados y validados bajo mi criterio como arquitecto de la solución.
* **Uso de IA como apoyo:** Se utilizaron herramientas de Inteligencia Artificial como apoyo de productividad para tareas operativas como refinamiento de redacción técnica, organización del documento, revisión de formato y aceleración de tareas repetitivas. La toma de decisiones arquitectónicas, el criterio técnico y la dirección de la solución permanecen bajo responsabilidad del autor.

---

## 🎨 Recursos de la solución

### 📢 Presentación del proyecto

Para visualizar el pitch de la solución, los objetivos estratégicos y el resumen ejecutivo orientado a stakeholders, se incluye la siguiente presentación:

👉 **[Presentación Ejecutiva en Canva](https://canva.link/fayq02xu8rbjq4x)**

### 📄 Documento de arquitectura principal

El diseño detallado de la solución, incluyendo diagramas C4, decisiones arquitectónicas, justificaciones técnicas, seguridad, nube, auditoría, autenticación, alta disponibilidad y monitoreo, se encuentra en la raíz del repositorio:

* `Diseño de Arquitectura de Solución (SADD) - Plataforma de Banca Digital BP.pdf`

---

## 📊 Arquitectura como Código: Modelo C4 con Structurizr

Para garantizar consistencia técnica y trazabilidad en los diagramas, el modelo C4 fue definido mediante **Architecture as Code (AaC)** utilizando **Structurizr DSL**.

El archivo principal del modelo se encuentra en:

* `workspace.dsl`

Este archivo permite visualizar y mantener los diagramas de:

* C4 Nivel 1 — Contexto
* C4 Nivel 2 — Contenedores
* C4 Nivel 3 — Componentes

---

## 🚀 Ejecución local de los diagramas

Para renderizar el modelo C4 de forma interactiva, se puede utilizar Structurizr Local mediante Docker.

Desde la raíz del repositorio, ejecutar:

```bash
docker run -it --rm -p 8080:8080 -v ${PWD}:/usr/local/structurizr structurizr/structurizr local
```

Luego abrir en el navegador:

```text
http://localhost:8080
```

---

## ⚠️ Nota sobre resolución de diagramas

Los diagramas incluidos dentro del PDF pueden perder nitidez debido a la compresión propia del documento. Por esta razón, las imágenes de los diagramas C4 se incluyen también de forma independiente en alta resolución dentro de la carpeta:

* `/diagrams`

Esto permite revisar con mayor claridad los nombres de componentes, protocolos, relaciones, patrones y controles de seguridad representados en la arquitectura.

---

## 🏗️ Resumen de la stack tecnológica propuesta

* **Frontends:** Angular 18 con TypeScript y NgRx para la SPA web; Flutter 3 con Dart y patrón BLoC para la aplicación móvil multiplataforma.
* **Capa de acceso:** AWS API Gateway, Kong Gateway y AWS WAF.
* **Identidad y autenticación:** Keycloak 24 como proveedor OAuth 2.0 / OpenID Connect, con Authorization Code Flow + PKCE, MFA y lineamientos FAPI.
* **Backend:** Microservicios en Java 21 y Spring Boot 3 desplegados sobre infraestructura administrada en AWS.
* **Persistencia y eventos:** Amazon RDS PostgreSQL Multi-AZ, AWS ElastiCache Redis 7, AWS SQS FIFO y Amazon SNS.
* **Onboarding biométrico:** AWS Rekognition y Rekognition Face Liveness para reconocimiento facial y validación de vida.
* **Auditoría:** Event Sourcing, base de datos de auditoría inmutable, hash chain y almacenamiento con controles WORM.
* **Observabilidad:** Amazon CloudWatch, AWS X-Ray, métricas, logs, trazabilidad distribuida y alarmas operativas.

---

## 📌 Objetivo arquitectónico

La arquitectura busca satisfacer los siguientes atributos de calidad:

* Seguridad financiera y protección de datos sensibles.
* Alta disponibilidad mediante despliegue Multi-AZ.
* Tolerancia a fallos con timeouts, retries y circuit breakers.
* Escalabilidad horizontal para canales web y móvil.
* Bajo acoplamiento entre servicios mediante mensajería asíncrona.
* Auditoría completa e inmutable de acciones del cliente.
* Integración segura con sistemas Core, sistemas complementarios, proveedores de notificación y red interbancaria.
* Capacidad de evolución futura mediante componentes cohesionados y reutilizables.
