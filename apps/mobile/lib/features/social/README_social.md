features/social/
├── data/
│   ├── repositories/
│   │   └── social_repository_impl.dart
│   ├── sources/
│   │   └── social_storage_source.dart
│   ├── social_service.dart
│
├── domain/
│   ├── entities/
│   │   └── post.dart
│   ├── repositories/
│   │   └── social_repository.dart
│
├── presentation/
│   ├── pages/
│   │   └── social_feed_page.dart
│   ├── sheets/
│   │   └── create_post_sheet.dart
│   └── widgets/
│       └── post_card.dart
│
└── social_routes.dart
🚀 Flujo general
1️⃣ Usuario autenticado → /social
Muestra el feed social (SocialFeedPage).

Carga los posts desde Firestore.posts.

Cada publicación se renderiza con PostCard.

2️⃣ Crear publicación → botón ➕
Abre CreatePostSheet.

El usuario selecciona imagen o video + descripción.

Se sube el medio a Firebase Storage con SocialStorageSource.

Se guarda un documento posts/{postId} en Firestore con SocialService.

3️⃣ Feed en tiempo real
StreamBuilder escucha Firestore → colección posts.

Al crearse un nuevo post, aparece automáticamente en el feed.

🧩 Colecciones y modelos
📦 posts/{postId}
Campo	Tipo	Descripción
authorId	string	UID del autor
type	string	"photo" o "video"
mediaUrls	list<string>	URLs de los medios subidos
thumbUrl	string	Miniatura si es video
caption	string	Texto del post
tags	list<string>	Hashtags extraídos (#ejemplo)
mentions	list<string>	Menciones extraídas (@usuario)
createdAt	timestamp	Fecha de creación
city	string	Ciudad del post
likeCount	int	Total de likes
commentCount	int	Total de comentarios
deleted	bool	Soft delete

🧾 Ejemplo de documento
json
Copiar código
{
  "authorId": "uid123",
  "type": "photo",
  "mediaUrls": ["https://.../photo.jpg"],
  "thumbUrl": null,
  "caption": "Gran partido en Bogotá #Final",
  "tags": ["Final"],
  "mentions": [],
  "createdAt": "2025-10-30T18:00:00Z",
  "city": "Bogotá",
  "likeCount": 0,
  "commentCount": 0,
  "deleted": false
}
⚙️ Servicios principales
🔹 SocialStorageSource
Maneja subida de medios (fotos/videos) al Storage.

Genera thumbnails con video_thumbnail.

Comprime imágenes con image y path_provider.

🔹 SocialRepositoryImpl
CRUD básico sobre la colección posts.

Lectura en tiempo real con Stream<List<Post>>.

🔹 SocialService
Orquesta la creación completa del post.

Sube medios → genera datos → guarda documento.

Extrae hashtags y menciones del caption.

🧠 Dependencias necesarias
yaml
Copiar código
dependencies:
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.3
  cloud_firestore: ^5.2.1
  firebase_storage: ^12.1.3
  image_picker: ^1.1.2
  image: ^4.2.0
  video_thumbnail: ^0.5.3
  path_provider: ^2.1.2
🔐 Seguridad
Verifica que hayas desplegado las reglas incluidas en:

firestore.rules

storage.rules

👉 Comando:

bash
Copiar código
firebase deploy --only firestore:rules,storage:rules
🧩 Integración con el router
Asegúrate de importar el módulo en tu archivo global:

dart
Copiar código
import '../features/social/social_routes.dart';

final GoRouter router = GoRouter(
  routes: [
    ...socialRoutes,
    GoRoute(path: '/', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/feed', builder: (_, __) => const FeedPage()),
  ],
);
Ruta del feed social:

dart
Copiar código
context.go('/social');
📱 Pruebas locales
1️⃣ Abre el emulador de Firebase o usa tu proyecto real.
2️⃣ Ejecuta:

bash
Copiar código
flutter run
3️⃣ Inicia sesión (por ahora manual).
4️⃣ Navega a /social.
5️⃣ Crea un post con foto o video.
6️⃣ Verifica que aparezca instantáneamente en el feed.

🧪 Próximas fases
Fase	Descripción
💬 Comentarios	Crear módulo post_comments (respuestas, hilos, conteo)
❤️ Likes reales	Crear subcolección post_likes/{postId}/likes/{uid}
📣 Notificaciones	Enviar push con FirebaseMessaging en nuevos likes/comentarios
🧠 Recomendaciones	Feed personalizado por ciudad o jugadores seguidos
🔒 Moderación	Integrar reportes y filtrado de lenguaje ofensivo

👨‍💻 Créditos técnicos
Arquitectura: Flutter Clean Architecture (Data / Domain / Presentation)

Backend: Firebase (Firestore + Storage + Functions)

Framework: Flutter 3.22+ (Dart 3.4+)

Diseño: Tema oscuro moderno (coherente con theme.dart)

Autor: Brandon Rocha — DraftClub Team

✅ Estado actual del módulo
Elemento	Estado
Modelo Post	✅ Listo
Repositorio Firestore	✅ Implementado
Subida de medios (Storage)	✅ Funcional
UI Feed + PostCard	✅ Completa
Creación de post (modal)	✅ Versión simulada
Seguridad (rules)	✅ Activa
Documentación	✅ Este archivo

📌 Resumen técnico rápido
Entrada del usuario →
CreatePostSheet → selecciona medio y texto →
SocialService.createPost() →
→ SocialStorageSource.uploadPhoto/Video()
→ SocialRepositoryImpl.createPost()
→ Firestore.posts →
→ SocialFeedPage (StreamBuilder) muestra el post.

🎯 Todo el flujo ocurre en < 3 segundos con red estable.

🔗 Versión actual: 1.0.0
Última actualización: Octubre 2025