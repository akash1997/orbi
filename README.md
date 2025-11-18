# orbi

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Data Persistence

The application stores data in Docker volumes, which persist across container restarts:

- **orbi-data**: Contains the SQLite database, uploaded recordings, and speaker embeddings
- **orbi-models**: Contains cached ML models (downloaded on first run)

### Running Modes

**Production Mode (Data Persistent):**
```bash
make up          # or: docker-compose up -d
```
- Source code is baked into the Docker image
- Data persists in Docker volumes
- No hot-reload

**Development Mode (Hot-Reload + Persistent Data):**
```bash
make dev         # or: docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```
- Source code is mounted for hot-reload
- Data still persists in Docker volumes
- Code changes reflected immediately (for API)
- Worker requires manual restart after code changes

### Data Management

**View data:**
```bash
# Check database content
docker exec orbi-api python3 -c "from database.session import SessionLocal; from database.models import AudioFile; db = SessionLocal(); print(f'Total files: {db.query(AudioFile).count()}')"

# List volumes
docker volume ls | grep orbi
```

**Backup data:**
```bash
# Backup database and recordings
docker run --rm -v orbi_orbi-data:/data -v $(pwd):/backup alpine tar czf /backup/orbi-backup.tar.gz -C /data .
```

**Reset data (CAUTION - deletes all data):**
```bash
docker-compose down -v
```

