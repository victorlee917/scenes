/// content.payload에서 타입별 이미지 위치를 뽑는다. 앱 content_repository의
/// _hydrateUrls와 동일한 키 매핑:
///   - photo: thumb_path / storage_path (scene_media 버킷)
///   - film:  poster_storage_path(캐시) / poster_source_url(TMDB CDN, 외부)
///   - music: album_art_url (Spotify CDN, 외부 — 캐시 안 함)
///   - place: mapbox_static_storage_path (scene_media 버킷)
///
/// `path`가 있으면 service-role로 서명, 없고 `url`만 있으면 그 외부 URL을 그대로.

export function contentImageRef(
  type: string,
  payload: Record<string, unknown>
): { path: string | null; url: string | null } {
  const s = (k: string) => {
    const v = payload[k];
    return typeof v === "string" && v.length > 0 ? v : null;
  };
  switch (type) {
    case "photo":
      return { path: s("thumb_path") ?? s("storage_path"), url: null };
    case "film":
      return { path: s("poster_storage_path"), url: s("poster_source_url") };
    case "music":
      return { path: null, url: s("album_art_url") };
    case "place":
      return { path: s("mapbox_static_storage_path"), url: null };
    default:
      return { path: null, url: null };
  }
}
