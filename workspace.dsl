workspace "BP — Banca por Internet" "Modelo Unificado de Arquitectura (C4 Niveles 1, 2 y 3)" {

    model {

        # ─── ACTORES ──────────────────────────────────────────────────────────
        cliente = person "Cliente / Usuario" "Usuario del banco que accede vía SPA web o aplicación móvil para consultar saldos, realizar transferencias y pagos."

        # ─── SISTEMAS EXTERNOS ────────────────────────────────────────────────
        coreBanking = softwareSystem "Core Banking Platform" "Sistema legado interno que contiene datos básicos de clientes, cuentas, productos financieros y movimientos bancarios." {
            tags "External System"
        }

        sistemaCompl = softwareSystem "Sistema Complementario" "Sistema independiente que provee información detallada del cliente cuando la consulta requiere mayor profundidad de datos." {
            tags "External System"
        }

        notificaciones = softwareSystem "Servicios de Notificación" "AWS SES para email transaccional y Twilio para SMS. Envían alertas de movimientos, confirmaciones de transacción y OTPs de autenticación al cliente." {
            tags "External System"
        }

        redInterbank = softwareSystem "Red Interbancaria" "ACH Colombia y SWIFT para el procesamiento de transferencias interbancarias nacionales e internacionales." {
            tags "External System"
        }

        rekognition = softwareSystem "AWS Rekognition + Textract" "Reconocimiento facial (Face Liveness, CompareFaces, IndexFaces) y OCR de documentos de identidad para el proceso de Onboarding." {
            tags "External System"
        }

        # ─── SISTEMA PRINCIPAL (CON AGRUPACIONES RE ESTRUCTURADAS) ────────────
        bancaBP = softwareSystem "Sistema de Banca por Internet [BP]" "Plataforma digital multicanal de BP: SPA Angular, App Móvil Flutter, microservicios en AWS EKS, API Gateway Kong y autenticación OAuth 2.0 con Keycloak." {
            tags "BP Internal"

            # GRUPO 1: Canales Digitales (Frontend)
            group "Canales Digitales" {
                spaAngular = container "SPA Web — Angular" "Interfaz web de banca digital. Permite consultar saldos, ver histórico de movimientos, realizar transferencias y pagos." "Angular 18 / TypeScript / NgRx" {
                    tags "Web Frontend"
                }

                appFlutter = container "App Móvil — Flutter" "Aplicación móvil iOS y Android con onboarding biométrico, autenticación por huella o facial, y operaciones bancarias completas." "Flutter 3 / Dart / BLoC" {
                    tags "Mobile App"
                }
            }

            # GRUPO 2: Capa de Seguridad y Borde (Edge)
            group "Seguridad y Borde" {
                keycloak = container "OAuth2 Server — Keycloak" "Servidor de identidad OAuth 2.0 / OIDC. Gestiona autenticación con PKCE, MFA (TOTP, SMS OTP, WebAuthn), sesiones y cumplimiento FAPI 2.0." "Keycloak 24 / Java / EKS HA" {
                    tags "Identity Provider"
                }

                apiGateway = container "API Gateway + WAF" "Punto de entrada único para todos los microservicios. Provee rate limiting, validación de tokens JWT, enrutamiento, circuit breaker y protección DDoS / OWASP Top 10." "AWS API Gateway + Kong + AWS WAF" {
                    tags "Gateway"

                    waf = component "WAF + Rate Limiter" "Primera línea de defensa. Filtra tráfico según reglas OWASP Top 10 (SQLi, XSS, LFI), aplica throttling por IP y por clientId. Bloquea IPs en listas negras y detecta patrones de DDoS." "AWS WAF v2 + Kong Rate Limiting Plugin"
                    tokenValidator = component "Token Validator" "Valida el JWT Bearer Token: firma RS256 contra JWKS de Keycloak, expiración (exp), emisor (iss), audiencia (aud) y claims de scope. Rechaza tokens revocados o malformados con HTTP 401." "AWS Lambda Authorizer / JWT Introspection / JWKS"
                    requestRouter = component "Request Router" "Enruta la petición validada al microservicio correspondiente según el path y versión de API. Aplica balanceo de carga Round Robin entre réplicas EKS. Añade headers de correlación (X-Request-ID)." "Kong Routes + AWS API Gateway Integrations"
                    circuitBreaker = component "Circuit Breaker" "Previene cascadas de fallos hacia microservicios. Estado CLOSED (normal) → OPEN (umbral 50% errores en 10 s) → HALF-OPEN (sondeo cada 30 s). Respuesta fallback con HTTP 503 + Retry-After." "Resilience4j CircuitBreaker + Retry + Timeout"
                }
            }

            # GRUPO 3: Servicios de Negocio Síncronos (Core)
            group "Microservicios de Negocio" {
                customerSvc = container "Customer Data Service" "Orquesta y provee datos del cliente con patrón Cache-Aside sobre Redis. Consulta Core Banking y Sistema Complementario mediante adaptadores." "Spring Boot 3 / Java 21 / EKS" {
                    tags "Microservice"

                    customerController = component "CustomerController" "Controlador REST que expone GET /api/v1/customers/{id} y GET /api/v1/customers/{id}/profile. Valida el request (Bean Validation), extrae el userId del JWT y delega al servicio de aplicación." "Spring MVC @RestController"
                    customerQuerySvc = component "CustomerQueryService" "Caso de uso central: orquesta el CacheProxy, el CoreBankingAdapter y el ComplementaryAdapter para construir el perfil completo del cliente. Aplica reglas de data minimization según el scope del token." "Spring @Service / Application Use Case"
                    cacheProxy = component "CacheProxy" "Implementa el patrón Cache-Aside (Lazy Loading). Genera la clave Redis bp:{userId}:{dataType}:v1, verifica si existe (MISS/HIT), y en caso de MISS consulta el backend y almacena el resultado con el TTL definido por política." "Spring AOP @Around / Cache-Aside Pattern / Redis"
                    coreBankingAdapter = component "CoreBankingAdapter" "Anticorruption Layer que abstrae el protocolo del Core Banking (REST/SOAP). Traduce contratos XML/JSON legados a DTOs internos. Aplica Retry con Exponential Backoff (3 intentos, jitter) y timeout de 3 s." "Spring @Component / Feign Client / Resilience4j Retry"
                    complAdapter = component "ComplementaryAdapter" "Consulta el Sistema Complementario para obtener información detallada del cliente (scoring, segmentación, historial extendido). Timeout de 2 s. Resultado incluido en la clave de caché del perfil completo." "Spring @Component / WebClient"
                    invalidator = component "CacheInvalidator" "Escucha eventos de actualización del Core Banking (webhook o cola SQS) para invalidar entradas de Redis antes del TTL natural. Garantiza consistencia eventual cuando el Core es modificado por canales externos (cajeros, sucursales)." "Spring @EventListener / SQS Consumer"
                    auditPublisher1 = component "AuditEventPublisher" "Publica un evento CustomerQueriedEvent a la cola SQS FIFO de auditoría tras cada consulta exitosa. Incluye userId, timestamp, IP, userAgent y resultado. Implementa Outbox Pattern para atomicidad." "Spring @Component / AWS SQS FIFO Producer"
                }

                movementsSvc = container "Movements Service" "Consulta y paginación del histórico de movimientos del cliente desde el Core Banking. Soporta filtros por fecha, tipo y monto." "Spring Boot 3 / Java 21 / EKS" {
                    tags "Microservice"
                }

                transferSvc = container "Transfer Service" "Procesa transferencias entre cuentas propias e interbancarias mediante el patrón SAGA. Publica eventos de auditoría y notificación a SQS FIFO." "Spring Boot 3 / Java 21 / EKS" {
                    tags "Microservice"

                    transferController = component "TransferController" "Controlador REST: POST /api/v1/transfers (cuenta propia) y POST /api/v1/transfers/interbank. Valida el body con Bean Validation, verifica el scope 'transfer' en el JWT y genera el idempotency-key." "Spring MVC @RestController"
                    transferHandler = component "TransferCommandHandler" "Orquestador SAGA: ejecuta la secuencia validar → reservar fondos → ejecutar débito/crédito → confirmar → publicar eventos. Ante cualquier fallo invoca la compensación correspondiente (rollback). Garantiza exactamente una ejecución por idempotency-key." "CQRS Command Handler / Saga Orchestrator Pattern"
                    transferValidator = component "TransferValidator" "Valida las precondiciones de negocio: saldo suficiente, límite diario del cliente, estado de la cuenta destino, listas restrictivas SARLAFT y cuentas bloqueadas. Rechaza con código de error negocio específico." "Spring @Component / Domain Service"
                    achAdapter = component "ACHAdapter" "Envía órdenes de transferencia a la red ACH Colombia. Formatea mensajes ISO 20022 (pacs.008), firma el mensaje con certificado digital y maneja los códigos de respuesta ACH (R-codes). mTLS obligatorio." "Spring @Component / ISO 20022 / mTLS"
                    swiftAdapter = component "SWIFTAdapter" "Integra con SWIFT Alliance para transferencias internacionales. Genera mensajes MT103 (legacy) y pacs.008 MX (ISO 20022). Valida IBAN/BIC y maneja ACKs/NAKs de la red SWIFT." "Spring @Component / SWIFT Alliance Gateway / ISO 20022"
                    auditPublisher2 = component "AuditEventPublisher" "Publica TransferExecutedEvent o TransferFailedEvent a la cola SQS FIFO de auditoría de forma atómica con la transacción mediante el Outbox Pattern. Incluye monto, cuentas (tokenizadas), resultado y traza de compensación si aplica." "Outbox Pattern / AWS SQS FIFO Producer"
                    notifPublisher = component "NotificationEventPublisher" "Publica NotificationRequestedEvent a la cola SQS estándar para que el Notification Service informe al cliente sobre el resultado de su transferencia. Incluye canal preferido, monto y referencia." "Spring @Component / AWS SQS Producer"
                }

                onboardingSvc = container "Onboarding Service" "Registra nuevos clientes: captura y verifica documento con Textract, valida liveness y compara facial con Rekognition, crea credenciales en Keycloak." "Python 3.12 / Lambda" {
                    tags "Microservice"
                }
            }

            # GRUPO 4: Procesamiento Asíncrono y Soporte
            group "Soporte e Ingesta Asíncrona" {
                notifSvc = container "Notification Service" "Consume eventos de SQS y envía notificaciones multicanal al cliente: email (AWS SES), SMS (Twilio) y push notifications (FCM/APNs)." "Node.js 20 / Lambda" {
                    tags "Microservice"
                }

                auditSvc = container "Audit Service" "Consume eventos de auditoría desde SQS FIFO de forma idempotente y los persiste de forma inmutable en el Audit DB mediante Event Sourcing." "Java 21 / Spring Boot / EKS" {
                    tags "Microservice"

                    auditConsumer = component "AuditEventConsumer" "Consumer SQS FIFO que recibe mensajes de auditoría. Implementa deduplicación por eventId (tabla bloom filter en Redis) para garantizar idempotencia ante reintentos del bus. Deserializa y valida el esquema del evento." "Spring Integration / SQS Message Listener / Idempotent Consumer"
                    auditHandler = component "AuditCommandHandler" "Enriquece el evento con metadatos del servidor: timestamp authoritative, geolocalización aproximada por IP (GeoIP2), hash del userAgent, versión del esquema. Orquesta el cálculo del hash chain y delega la persistencia." "Spring @Service / Domain Command Handler"
                    hashChainSvc = component "HashChainService" "Calcula el hash de integridad encadenado: hashChain = SHA-256(prevEventHash + currentEventPayload). El primer evento de cada día usa como semilla el hash del bloque anterior (similar a blockchain). Cualquier alteración del registro histórico es detectable." "Spring @Component / Cryptographic Service / SHA-256"
                    auditRepo = component "AuditRepository" "Repositorio append-only que persiste eventos en PostgreSQL. Políticas a nivel de BD (Row-Level Security + GRANT solo INSERT) impiden UPDATE y DELETE. Los datos PII del payload se cifran con AWS KMS antes de persistir. Particionado por mes para consultas de auditoría eficientes." "Spring Data JPA / @Repository / WORM / AWS KMS"
                }
            }

            # GRUPO 5: Capa de Datos e Infraestructura Común
            group "Datos e Infraestructura" {
                auditDb = container "Audit DB" "Event store inmutable de todas las acciones del cliente. Append-only, WORM, hash chain verificable. Retención mínima 7 años (Circular SFC 052)." "PostgreSQL 15 / RDS Multi-AZ" {
                    tags "Database"
                }

                redisCache = container "Redis Cache" "Caché en memoria para datos frecuentes de clientes (perfil, cuentas, últimos movimientos) con patrón Cache-Aside. Cluster Mode con réplicas Multi-AZ." "AWS ElastiCache Redis 7 — Cluster Mode" {
                    tags "Database"
                }

                messageBus = container "Message Bus" "Bus de eventos asíncrono para desacoplar microservicios. Colas FIFO para auditoría (orden garantizado) y Standard para notificaciones. DLQ en ambas." "AWS SQS FIFO + SNS Fan-out" {
                    tags "Message Bus"
                }
            }
        }

        # ─── RELACIONES NIVEL 1 (CONTEXTO) ────────────────────────────────────
        cliente      -> bancaBP        "Consulta saldos e histórico, realiza transferencias y pagos" "HTTPS / TLS 1.3"
        bancaBP      -> coreBanking    "Consulta datos básicos de cliente, cuentas y movimientos" "REST / SOAP / mTLS"
        bancaBP      -> sistemaCompl   "Obtiene información detallada del cliente bajo demanda" "REST / HTTPS"
        bancaBP      -> notificaciones "Envía notificaciones de movimientos y alertas de seguridad" "SMTP / HTTPS"
        bancaBP      -> redInterbank   "Procesa órdenes de transferencia interbancaria" "ISO 20022 / SWIFT"

        # ─── RELACIONES NIVEL 2 (CONTENEDORES) ────────────────────────────────
        cliente      -> spaAngular     "Accede a banca web" "HTTPS / TLS 1.3"
        cliente      -> appFlutter     "Accede a banca móvil" "HTTPS / TLS 1.3"
        
        spaAngular   -> keycloak       "Autenticación OAuth 2.0" "HTTPS / OIDC"
        appFlutter   -> keycloak       "Autenticación OAuth 2.0" "HTTPS / OIDC"
        
        spaAngular   -> apiGateway     "API calls con JWT" "HTTPS / REST"
        appFlutter   -> apiGateway     "API calls con JWT" "HTTPS / REST"
        
        apiGateway   -> customerSvc    "GET /customers" "HTTPS / REST"
        apiGateway   -> movementsSvc   "GET /movements" "HTTPS / REST"
        apiGateway   -> transferSvc    "POST /transfers" "HTTPS / REST"
        apiGateway   -> notifSvc       "POST /notifications" "HTTPS / REST"
        apiGateway   -> onboardingSvc  "POST /onboarding" "HTTPS / REST"
        
        movementsSvc -> coreBanking    "Consulta movimientos" "REST / mTLS"
        transferSvc  -> coreBanking    "Débito y crédito" "REST / mTLS"
        transferSvc  -> redInterbank   "Envía orden ACH" "ISO 20022 / mTLS"
        notifSvc     -> messageBus     "Consume notificaciones" "AWS SQS"
        notifSvc     -> notificaciones "Envía email y SMS" "SMTP / HTTPS"
        onboardingSvc -> rekognition   "Verificación biométrica" "HTTPS / AWS SDK"
        onboardingSvc -> keycloak      "Crea usuario" "HTTPS / Admin REST API"
        
        customerSvc  -> redisCache     "Cache-Aside" "Redis Protocol"
        customerSvc  -> coreBanking    "Consulta básicos" "REST / mTLS"
        customerSvc  -> sistemaCompl   "Consulta extendidos" "REST / HTTPS"
        customerSvc  -> messageBus     "Publica consulta" "AWS SQS FIFO"
        transferSvc  -> messageBus     "Publica transferencia" "AWS SQS FIFO"
        auditSvc     -> messageBus     "Consume auditoría" "AWS SQS FIFO"
        auditSvc     -> auditDb        "Persiste eventos" "JDBC / TLS"

        # All services publish audit events (Resumido para limpiar la vista)
        customerSvc  -> messageBus   "Eventos auditoría" "SQS FIFO"
        transferSvc  -> messageBus   "Eventos auditoría" "SQS FIFO"

        # ─── RELACIONES NIVEL 3 (COMPONENTES INTERNOS) ────────────────────────
        waf            -> tokenValidator "Petición filtrada"
        tokenValidator -> requestRouter  "Token verificado"
        requestRouter  -> circuitBreaker "Petición enrutada"
        circuitBreaker -> customerController "Enruta GET /customers" "HTTPS"
        circuitBreaker -> transferController "Enruta POST /transfers" "HTTPS"

        customerController -> customerQuerySvc   "Delega consulta"
        customerQuerySvc   -> cacheProxy         "Verifica caché"
        cacheProxy         -> redisCache         "GET / SET" "Redis Protocol"
        cacheProxy         -> coreBankingAdapter "MISS: consulta"
        coreBankingAdapter -> coreBanking        "Consulta básicos" "mTLS"
        customerQuerySvc   -> complAdapter       "Consulta extendidos"
        complAdapter       -> sistemaCompl       "Consulta scoring" "HTTPS"
        customerQuerySvc   -> auditPublisher1    "Publica auditoría"
        auditPublisher1    -> messageBus         "Envía evento" "SQS FIFO"
        invalidator        -> cacheProxy         "Invalida caché"

        transferController -> transferHandler    "Ejecuta comando"
        transferHandler    -> transferValidator  "Valida negocio"
        transferHandler    -> achAdapter         "Orquesta ACH"
        achAdapter         -> redInterbank       "Transfiere fondos" "ISO 20022"
        transferHandler    -> swiftAdapter       "Orquesta SWIFT"
        swiftAdapter       -> redInterbank       "Transfiere internacional" "MT103"
        transferHandler    -> auditPublisher2    "Publica auditoría"
        auditPublisher2    -> messageBus         "Envía evento" "SQS FIFO"
        transferHandler    -> notifPublisher     "Publica notificación"
        notifPublisher     -> messageBus         "Envía evento" "SQS Standard"

        auditConsumer      -> messageBus         "Consume mensajes" "SQS FIFO"
        auditConsumer      -> auditHandler       "Pasa evento"
        auditHandler       -> hashChainSvc       "Solicita firmado"
        auditHandler       -> auditRepo          "Delega persistencia"
        auditRepo          -> auditDb            "INSERT append-only" "JDBC"
    }

    views {

        systemContext bancaBP "C4-L1-Context" {
            title "Diagrama de Contexto — C4 Nivel 1"
            include *
            autoLayout tb 300 300
            description "Vista de alto nivel del sistema de banca digital de BP y su entorno."
        }

        container bancaBP "C4-L2-Containers" {
            title "Diagrama de Contenedores — C4 Nivel 2"
            include *
            autoLayout tb 400 350
            description "Vista técnica estructurada por capas lógicas mediante agrupaciones de infraestructura."
        }

        component apiGateway "C4-L3-APIGateway" {
            title "Componentes — API Gateway Layer"
            include *
            autoLayout tb 250 250
            description "Filtros de seguridad, enrutamiento y resiliencia de entrada."
        }

        component customerSvc "C4-L3-CustomerService" {
            title "Componentes — Customer Data Service"
            include *
            autoLayout tb 250 250
            description "Orquestación de perfil de cliente con estrategia de caché."
        }

        component transferSvc "C4-L3-TransferService" {
            title "Componentes — Transfer Service"
            include *
            autoLayout tb 250 250
            description "Procesamiento transaccional de transferencias con patrón SAGA."
        }

        component auditSvc "C4-L3-AuditService" {
            title "Componentes — Audit Service"
            include *
            autoLayout tb 250 250
            description "Ingesta inmutable de eventos con encadenamiento criptográfico."
        }

        styles {
            element "Element" {
                metadata false
                description true
            }
            element "Person" {
                shape Person
                background #0f172a
                color #ffffff
                fontSize 15
                width 280
                height 160
            }
            element "Software System" {
                background #475569
                color #f8fafc
                shape RoundedBox
                fontSize 14
                width 340
                height 180
            }
            element "Container" {
                background #1e40af
                color #ffffff
                shape RoundedBox
                fontSize 14
                width 340
                height 180
            }
            element "Component" {
                shape Component
                background #0284c7
                color #ffffff
                fontSize 13
                width 350
                height 190
            }
            element "Web Frontend" {
                shape WebBrowser
                background #1d4ed8
            }
            element "Mobile App" {
                shape MobileDevicePortrait
                background #1d4ed8
                width 240
                height 200
            }
            element "Identity Provider" {
                background #1e3a8a
            }
            element "Gateway" {
                background #111827
            }
            element "Microservice" {
                background #2563eb
            }
            element "Database" {
                shape Cylinder
                background #065f46
                width 260
                height 180
            }
            element "Message Bus" {
                shape Pipe
                background #5b21b6
                width 300
                height 140
            }
            element "External System" {
                background #64748b
                color #f8fafc
            }
            element "BP Internal" {
                background #1e40af
            }
            relationship "Relationship" {
                color #94a3b8
                thickness 2
                fontSize 12
            }
        }

        theme default
    }
}