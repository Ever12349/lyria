import Foundation

enum Schema {
    /// v1. `user_hidden` is intentionally absent: remove-from-library deletes the track row.
    static let v1 = """
    CREATE TABLE fingerprints (
      fingerprint TEXT PRIMARY KEY,
      track_id TEXT NOT NULL UNIQUE,
      method TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE tracks (
      id TEXT PRIMARY KEY,
      path TEXT NOT NULL,
      aliases_json TEXT NOT NULL DEFAULT '[]',
      title TEXT NOT NULL,
      artist_name TEXT NOT NULL,
      album_name TEXT NOT NULL,
      artist_id TEXT,
      album_id TEXT,
      duration_ms INTEGER NOT NULL,
      year INTEGER NOT NULL DEFAULT 0,
      size INTEGER NOT NULL,
      mtime INTEGER NOT NULL,
      missing INTEGER NOT NULL DEFAULT 0,
      encoding_suspect INTEGER NOT NULL DEFAULT 0,
      icloud_offline INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE artists (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      sort_name TEXT NOT NULL,
      track_count INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE albums (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      artist_id TEXT,
      year INTEGER NOT NULL DEFAULT 0,
      track_count INTEGER NOT NULL DEFAULT 0,
      artwork_path TEXT
    );
    CREATE TABLE playlists (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE playlist_tracks (
      playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
      track_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      PRIMARY KEY (playlist_id, position)
    );
    CREATE UNIQUE INDEX idx_playlist_track_once ON playlist_tracks(playlist_id, track_id);
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE scan_roots (
      id INTEGER PRIMARY KEY,
      path TEXT NOT NULL UNIQUE,
      bookmark BLOB,
      enabled INTEGER NOT NULL DEFAULT 1
    );
    CREATE INDEX idx_tracks_artist ON tracks(artist_id);
    CREATE INDEX idx_tracks_album ON tracks(album_id);
    CREATE INDEX idx_tracks_path ON tracks(path);
    CREATE INDEX idx_playlist_tracks_track ON playlist_tracks(track_id);
    """
}
