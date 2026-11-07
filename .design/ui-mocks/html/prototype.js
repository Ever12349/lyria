"use strict";

const TRACKS = [
  { id: "t1", cn: "星际旅行", en: "Interstellar Voyage", artist: "Dreamscape", artistId: "dreamscape", album: "银河边缘", albumId: "edge", duration: 272 },
  { id: "t2", cn: "午夜信号", en: "Midnight Signal", artist: "Aurora Line", artistId: "aurora", album: "夜航电台", albumId: "radio", duration: 228 },
  { id: "t3", cn: "漂浮的城市", en: "Floating Cities", artist: "Neon Harbor", artistId: "neon", album: "云端漫步", albumId: "cloud", duration: 302 },
  { id: "t4", cn: "光的碎片", en: "Fragments of Light", artist: "Lumen", artistId: "lumen", album: "星尘集", albumId: "dust", duration: 251 },
  { id: "t5", cn: "深空静默", en: "Silent Deep Space", artist: "Void Choir", artistId: "void", album: "深空静默", albumId: "silence", duration: 380 },
];

const ARTISTS = [
  { id: "dreamscape", name: "Dreamscape", count: "12 首", showcase: true },
  { id: "aurora", name: "Aurora Line", count: "8 首" },
  { id: "neon", name: "Neon Harbor", count: "15 首" },
  { id: "lumen", name: "Lumen", count: "6 首" },
  { id: "void", name: "Void Choir", count: "9 首" },
  { id: "paper", name: "The Paper Kites", count: "11 首" },
  { id: "m83", name: "M83", count: "7 首" },
  { id: "boniver", name: "Bon Iver", count: "10 首" },
];

const ALBUMS = [
  { id: "edge", name: "银河边缘", artist: "Dreamscape", artistId: "dreamscape", year: "2024", showcase: true, countLabel: "8 首" },
  { id: "radio", name: "夜航电台", artist: "Aurora Line", artistId: "aurora", year: "2024" },
  { id: "cloud", name: "云端漫步", artist: "Neon Harbor", artistId: "neon", year: "2023" },
  { id: "dust", name: "星尘集", artist: "Lumen", artistId: "lumen", year: "2024" },
  { id: "silence", name: "深空静默", artist: "Void Choir", artistId: "void", year: "2022" },
  { id: "forest", name: "挪威的森林", artist: "Beyond", artistId: "beyond", year: "1993" },
  { id: "ordinary", name: "Ordinary Road", artist: "朴树", artistId: "pushu", year: "1994" },
  { id: "voyager", name: "Night Voyager", artist: "M83", artistId: "m83", year: "2011" },
];

const MORE_ARTISTS = [
  { id: "beyond", name: "Beyond" },
  { id: "pushu", name: "朴树" },
  { id: "nova", name: "Nova Relay" },
  { id: "tide", name: "Tide Theory" },
  { id: "glass", name: "Glass Ocean" },
  { id: "north", name: "Northroom" },
  { id: "lantern", name: "Lantern Kids" },
  { id: "staticg", name: "Static Garden" },
];

const MORE_ALBUMS = [
  { id: "orbit", name: "轨道余温", artist: "Dreamscape", artistId: "dreamscape", year: "2023" },
  { id: "letters", name: "极光来信", artist: "Aurora Line", artistId: "aurora", year: "2022" },
  { id: "harbor", name: "港湾夜色", artist: "Neon Harbor", artistId: "neon", year: "2021" },
  { id: "prism", name: "棱镜", artist: "Lumen", artistId: "lumen", year: "2020" },
  { id: "echo", name: "回声大厅", artist: "Void Choir", artistId: "void", year: "2023" },
  { id: "kites", name: "纸鸢", artist: "The Paper Kites", artistId: "paper", year: "2018" },
  { id: "hurry", name: "Hurry Up", artist: "M83", artistId: "m83", year: "2005" },
  { id: "emma", name: "For Emma", artist: "Bon Iver", artistId: "boniver", year: "2007" },
  { id: "woods", name: "林间", artist: "Beyond", artistId: "beyond", year: "1995" },
  { id: "y2k", name: "我去2000年", artist: "朴树", artistId: "pushu", year: "1999" },
  { id: "nova", name: "新星", artist: "Nova Relay", artistId: "nova", year: "2024" },
  { id: "tide", name: "潮汐表", artist: "Tide Theory", artistId: "tide", year: "2023" },
  { id: "glass", name: "玻璃海", artist: "Glass Ocean", artistId: "glass", year: "2022" },
  { id: "north", name: "北纬", artist: "Northroom", artistId: "north", year: "2021" },
  { id: "lantern", name: "灯塔", artist: "Lantern Kids", artistId: "lantern", year: "2019" },
  { id: "static", name: "静电", artist: "Static Garden", artistId: "staticg", year: "2020" },
];

const SONGBOOK = {
  edge: [["返航", "Return Path"], ["失重", "Weightless"], ["舷窗", "Porthole"], ["暗物质", "Dark Matter"]],
  radio: [["呼号", "Call Sign"], ["夜班", "Night Shift"], ["短波", "Shortwave"], ["无人应答", "No Answer"]],
  cloud: [["云层", "Cloud Layer"], ["霓虹雨", "Neon Rain"], ["高架", "Overpass"], ["回港", "Back to Harbor"]],
  dust: [["折射", "Refraction"], ["尘埃", "Dust"], ["白噪", "White Noise"], ["余光", "Afterglow"]],
  silence: [["无声", "No Sound"], ["低语", "Undertone"], ["空舱", "Empty Cabin"], ["远星", "Far Star"]],
  forest: [["挪威的森林", "Norwegian Wood"], ["海阔天空", "Boundless"], ["光辉岁月", "Glorious Years"], ["情人", "Lover"]],
  ordinary: [["平凡之路", "Ordinary Road"], ["白桦林", "White Birch"], ["那些花儿", "Those Flowers"], ["生如夏花", "Life Like Summer"]],
  voyager: [["Midnight City", "Midnight City"], ["Outro", "Outro"], ["Wait", "Wait"], ["Intro", "Intro"]],
  orbit: [["余温", "Afterheat"], ["滑行", "Glide"], ["近地点", "Perigee"], ["关机", "Power Down"]],
  letters: [["未寄出", "Unsent"], ["极光", "Aurora"], ["回信", "Reply"], ["邮票", "Postage"]],
  harbor: [["潮灯", "Tide Light"], ["缆绳", "Mooring"], ["雾笛", "Foghorn"], ["靠岸", "Docking"]],
  prism: [["光谱", "Spectrum"], ["切面", "Facet"], ["色散", "Dispersion"], ["焦点", "Focus"]],
  echo: [["回声", "Echo"], ["穹顶", "Dome"], ["合唱", "Chorus"], ["尾音", "Cadence"]],
  kites: [["纸鸢", "Paper Kite"], ["风", "Wind"], ["线", "String"], ["草地", "Grass"]],
  hurry: [["Teenagers", "Teenagers"], ["Kim & Jessie", "Kim & Jessie"], ["Don't Save Us", "Don't Save Us"], ["Graveyard Girl", "Graveyard Girl"]],
  emma: [["Flume", "Flume"], ["Skinny Love", "Skinny Love"], ["The Wolves", "The Wolves"], ["Re: Stacks", "Re: Stacks"]],
  woods: [["真的爱你", "Truly Love You"], ["喜欢你", "Loving You"], ["大地", "The Earth"], ["灰色轨迹", "Grey Track"]],
  y2k: [["New Boy", "New Boy"], ["火车", "Train"], ["世界的末日", "End of the World"], ["在希望的田野上", "Fields of Hope"]],
  nova: [["点火", "Ignition"], ["弹道", "Trajectory"], ["对接", "Dock"], ["再入", "Reentry"]],
  tide: [["涨潮", "Flood"], ["退潮", "Ebb"], ["月相", "Moon Phase"], ["盐", "Salt"]],
  glass: [["玻璃", "Glass"], ["海平面", "Sea Level"], ["折射光", "Refracted"], ["沉船", "Wreck"]],
  north: [["北纬", "Latitude"], ["暖气", "Radiator"], ["窗", "Window"], ["雪", "Snow"]],
  lantern: [["灯塔", "Lighthouse"], ["守夜", "Night Watch"], ["光束", "Beam"], ["归航", "Homeward"]],
  static: [["静电", "Static"], ["天线", "Antenna"], ["频道", "Channel"], ["关机音", "Sign Off"]],
};

ARTISTS.push(...MORE_ARTISTS);
ALBUMS.push(...MORE_ALBUMS);

ALBUMS.forEach((album) => {
  (SONGBOOK[album.id] || []).forEach((pair, index) => {
    TRACKS.push({
      id: `t${TRACKS.length + 1}`,
      cn: pair[0],
      en: pair[1],
      artist: album.artist,
      artistId: album.artistId,
      album: album.name,
      albumId: album.id,
      duration: 154 + ((TRACKS.length * 29 + index * 11) % 246),
    });
  });
});

const state = {
  scene: "app",
  nav: "library",
  detail: null,
  libraryEmpty: false,
  query: "",
  nowId: "t1",
  selectedId: "t1",
  removedIds: [],
  menu: null,
  playing: true,
  position: 108,
  volume: 0.6,
  prevVol: 0.6,
  shuffle: false,
  repeat: "off",
  queueOpen: false,
  queue: ["t1", "t2", "t3", "t4", "t5"],
  httpOn: true,
  launchOn: false,
  scanning: false,
  manageOpen: false,
  renaming: null,
  focusRename: false,
  toast: "",
  idle: false,
  savedPlaying: true,
  playlists: [
    { id: "night", name: "深夜航行", sub: "18 首", showcase: true, tracks: ["t1", "t2", "t3", "t4", "t5"] },
    { id: "focus", name: "专注深空", sub: "24 首", tracks: ["t5", "t2", "t4"] },
    { id: "fav", name: "收藏夹", sub: "", tracks: [] },
    { id: "weekend", name: "周末漫游", sub: "11 首", tracks: ["t3", "t1"] },
    { id: "dustpick", name: "星尘精选", sub: "9 首", tracks: ["t4", "t1"] },
    { id: "commute", name: "通勤波段", sub: "15 首", tracks: ["t2", "t3"] },
    { id: "rain", name: "雨夜电台", sub: "7 首", tracks: ["t5", "t2"] },
  ],
};

const favorites = state.playlists.find((playlist) => playlist.id === "fav");
favorites.tracks = TRACKS.map((track) => track.id);
favorites.sub = `${TRACKS.length} 首`;

let returnTo = null;
let seq = 1;
let toastTimer = 0;
let dragging = null;
let renameOrigin = "";

const $ = (id) => document.getElementById(id);

function esc(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[ch]));
}

function fmt(seconds) {
  const total = Math.max(0, Math.floor(seconds));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

function trackById(id) {
  return TRACKS.find((track) => track.id === id) || null;
}

function albumById(id) {
  return ALBUMS.find((album) => album.id === id) || null;
}

function playlistById(id) {
  return state.playlists.find((playlist) => playlist.id === id) || null;
}

function knownArtist(id) {
  return ARTISTS.some((artist) => artist.id === id) || ALBUMS.some((album) => album.artistId === id);
}

function artistById(id) {
  const found = ARTISTS.find((artist) => artist.id === id);
  if (found) return found;
  const album = ALBUMS.find((item) => item.artistId === id);
  if (!album) return null;
  return { id, name: album.artist, count: "", virtual: true };
}

function albumsOf(artistId) {
  return ALBUMS.filter((album) => album.artistId === artistId);
}

function isListed(id) {
  return !state.removedIds.includes(id);
}

function tracksOfArtist(artistId) {
  return TRACKS.filter((track) => track.artistId === artistId && isListed(track.id));
}

function tracksOfAlbum(album) {
  return TRACKS.filter((track) => track.albumId === album.id && isListed(track.id));
}

function tracksOfPlaylist(playlist) {
  return playlist.tracks.map(trackById).filter(Boolean);
}

function isIdle() {
  return state.scene === "app"
    && state.libraryEmpty
    && state.nav === "library"
    && !state.detail
    && !state.query.trim();
}

function shownTrack() {
  if (isIdle()) return null;
  return trackById(state.nowId);
}

function syncIdle() {
  const idle = isIdle();
  if (idle === state.idle) return;
  if (idle) {
    state.savedPlaying = state.playing;
    state.playing = false;
  } else {
    state.playing = state.savedPlaying;
  }
  state.idle = idle;
}

function hashFor() {
  if (state.scene === "menubar") return "#/menubar";
  if (state.scene === "chrome") return "#/chrome";
  if (state.query.trim()) return "#/library";
  if (state.detail) return `#/${state.detail.type}/${state.detail.id}`;
  if (state.libraryEmpty && state.nav === "library") return "#/empty-library";
  return `#/${state.nav}`;
}

function applyHash() {
  const raw = (location.hash || "#/library").replace(/^#\/?/, "");
  const [kind, id] = raw.split("/");
  state.scene = "app";
  state.detail = null;
  state.libraryEmpty = false;
  state.nav = "library";
  if (kind === "menubar") state.scene = "menubar";
  else if (kind === "chrome") state.scene = "chrome";
  else if (kind === "empty-library") {
    state.libraryEmpty = true;
    state.nav = "library";
  } else if (kind === "artist" && knownArtist(id)) {
    state.nav = "artists";
    state.detail = { type: "artist", id };
  } else if (kind === "album" && albumById(id)) {
    state.nav = "albums";
    state.detail = { type: "album", id };
  } else if (kind === "playlist" && playlistById(id)) {
    state.nav = "playlists";
    state.detail = { type: "playlist", id };
  } else if (["library", "artists", "albums", "playlists", "settings"].includes(kind)) {
    state.nav = kind;
  }
}

function push() {
  seq += 1;
  history.pushState({ lyria: seq }, "", hashFor());
}

function navigate(partial) {
  Object.assign(state, partial);
  push();
  render();
}

function toast(text) {
  state.toast = text;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    state.toast = "";
    const node = $("toast");
    if (node) {
      node.classList.remove("show");
      node.textContent = "";
    }
  }, 1600);
}

function clearSearchField() {
  const input = $("q");
  if (input) input.value = "";
  state.query = "";
  if (returnTo) {
    state.nav = returnTo.nav;
    state.detail = returnTo.detail;
    state.libraryEmpty = returnTo.libraryEmpty;
    returnTo = null;
  }
}

function onSearch(value) {
  const wasEmpty = !state.query.trim();
  const nowEmpty = !value.trim();
  state.query = value;
  if (!nowEmpty && wasEmpty) {
    returnTo = {
      nav: state.nav,
      detail: state.detail,
      libraryEmpty: state.libraryEmpty,
    };
    state.detail = null;
    state.nav = "library";
  }
  if (nowEmpty && returnTo) {
    state.nav = returnTo.nav;
    state.detail = returnTo.detail;
    state.libraryEmpty = returnTo.libraryEmpty;
    returnTo = null;
  }
  history.replaceState(history.state, "", hashFor());
  render();
}

function matchTrack(track, query) {
  const needle = query.toLowerCase();
  return [track.cn, track.en, track.artist, track.album].some((field) => field.toLowerCase().includes(needle));
}

function shuffled(list) {
  const copy = list.slice();
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swap = Math.floor(Math.random() * (index + 1));
    [copy[index], copy[swap]] = [copy[swap], copy[index]];
  }
  return copy;
}

function playIds(ids, shuffle) {
  const list = ids.map(trackById).filter(Boolean).map((track) => track.id);
  if (!list.length) {
    toast("没有可播放的曲目");
    render();
    return;
  }
  const order = shuffle ? shuffled(list) : list.slice();
  state.queue = order;
  state.nowId = order[0];
  state.position = 0;
  state.playing = true;
  state.savedPlaying = true;
  if (shuffle) state.shuffle = true;
  render();
}

function playTrack(id) {
  if (!trackById(id) || isIdle()) return;
  state.nowId = id;
  state.selectedId = id;
  state.position = 0;
  state.playing = true;
  state.savedPlaying = true;
  if (!state.queue.includes(id)) state.queue.push(id);
  state.menu = null;
  render();
}

function playNext(id) {
  const track = trackById(id);
  if (!track || isIdle()) return;
  const queue = state.queue.filter((item) => item !== id && trackById(item));
  const index = queue.indexOf(state.nowId);
  if (index < 0) queue.unshift(id);
  else queue.splice(index + 1, 0, id);
  state.queue = queue;
  state.menu = null;
  toast(`「${track.cn}」将在下一首播放`);
  render();
}

function refreshPlaylistSub(playlist) {
  if (playlist.showcase) return;
  playlist.sub = playlist.tracks.length ? `${playlist.tracks.length} 首` : "0 首";
}

function addTrackToPlaylist(playlistId, trackId) {
  const playlist = playlistById(playlistId);
  const track = trackById(trackId);
  if (!playlist || !track) return;
  state.menu = null;
  if (playlist.tracks.includes(trackId)) {
    toast("已在该播放列表中");
    render();
    return;
  }
  playlist.tracks.push(trackId);
  refreshPlaylistSub(playlist);
  toast(`已加入「${playlist.name}」`);
  render();
}

function removeFromPlaylist(playlistId, trackId) {
  const playlist = playlistById(playlistId);
  if (!playlist) return;
  playlist.tracks = playlist.tracks.filter((id) => id !== trackId);
  refreshPlaylistSub(playlist);
  state.menu = null;
  toast(`已从「${playlist.name}」移除`);
  render();
}

function removeFromLibrary(id) {
  const track = trackById(id);
  if (!track || state.removedIds.includes(id)) return;
  state.removedIds.push(id);
  if (state.selectedId === id) state.selectedId = null;
  state.menu = null;
  toast(`已从曲库移除「${track.cn}」`);
  render();
}

function addToQueue(ids) {
  let added = 0;
  ids.forEach((id) => {
    if (trackById(id) && !state.queue.includes(id)) {
      state.queue.push(id);
      added += 1;
    }
  });
  state.queueOpen = true;
  state.menu = null;
  toast(added ? `已加入队列 ${added} 首` : "已在队列中");
  render();
}

function goNext(fromUser) {
  if (isIdle()) return;
  const current = trackById(state.nowId);
  const ids = state.queue.filter((id) => trackById(id));
  if (!current || !ids.length) return;
  if (!fromUser && state.repeat === "one") {
    state.position = 0;
    state.playing = true;
    render();
    return;
  }
  const index = ids.indexOf(state.nowId);
  let next = -1;
  if (state.shuffle && ids.length > 1) {
    do {
      next = Math.floor(Math.random() * ids.length);
    } while (ids[next] === state.nowId);
  } else if (index >= 0 && index + 1 < ids.length) next = index + 1;
  else if (state.repeat === "all" || fromUser) next = 0;
  if (next < 0) {
    state.playing = false;
    state.savedPlaying = false;
    state.position = current.duration;
    render();
    return;
  }
  state.nowId = ids[next];
  state.position = 0;
  state.playing = true;
  state.savedPlaying = true;
  render();
}

function goPrev() {
  if (isIdle()) return;
  const current = trackById(state.nowId);
  const ids = state.queue.filter((id) => trackById(id));
  if (!current || !ids.length) return;
  if (state.position > 2) {
    state.position = 0;
    paintTimes();
    return;
  }
  const index = ids.indexOf(state.nowId);
  if (index > 0) state.nowId = ids[index - 1];
  else if ((state.repeat === "all" || state.shuffle) && ids.length) state.nowId = ids[ids.length - 1];
  state.position = 0;
  state.playing = true;
  state.savedPlaying = true;
  render();
}

function togglePlay() {
  if (!shownTrack()) return;
  state.playing = !state.playing;
  state.savedPlaying = state.playing;
  render();
}

function seekBy(delta) {
  const track = shownTrack();
  if (!track) return;
  state.position = Math.min(track.duration, Math.max(0, state.position + delta));
  paintTimes();
}

function cycleRepeat() {
  const order = ["off", "all", "one"];
  state.repeat = order[(order.indexOf(state.repeat) + 1) % order.length];
  render();
}

function selectNav(nav) {
  state.menu = null;
  state.query = "";
  const input = $("q");
  if (input) input.value = "";
  returnTo = null;
  state.manageOpen = false;
  state.renaming = null;
  navigate({ scene: "app", nav, detail: null });
}

function openDetail(type, id) {
  state.menu = null;
  state.query = "";
  const input = $("q");
  if (input) input.value = "";
  returnTo = null;
  state.renaming = null;
  const nav = type === "artist" ? "artists" : type === "album" ? "albums" : "playlists";
  navigate({ scene: "app", nav, detail: { type, id } });
}

function goBack() {
  if (history.state && history.state.lyria > 1) {
    history.back();
    return;
  }
  state.detail = null;
  state.renaming = null;
  history.replaceState(history.state, "", hashFor());
  render();
}

function nextPlaylistName() {
  const names = new Set(state.playlists.map((playlist) => playlist.name));
  if (!names.has("新播放列表")) return "新播放列表";
  let index = 2;
  while (names.has(`新播放列表 ${index}`)) index += 1;
  return `新播放列表 ${index}`;
}

function createPlaylist() {
  const playlist = {
    id: `pl_${Date.now()}`,
    name: nextPlaylistName(),
    sub: "0 首",
    tracks: [],
  };
  state.playlists.unshift(playlist);
  state.query = "";
  const input = $("q");
  if (input) input.value = "";
  returnTo = null;
  navigate({ scene: "app", nav: "playlists", detail: { type: "playlist", id: playlist.id } });
}

function commitRename(value) {
  if (!state.renaming) return;
  const playlist = playlistById(state.renaming);
  state.renaming = null;
  if (playlist) {
    const name = value.trim();
    playlist.name = name || renameOrigin;
    if (playlist.name !== renameOrigin) toast("已重命名");
  }
  render();
}

function deletePlaylist(id) {
  const playlist = playlistById(id);
  if (!playlist) return;
  if (!confirm(`删除播放列表「${playlist.name}」？`)) return;
  state.playlists = state.playlists.filter((item) => item.id !== id);
  state.detail = null;
  state.renaming = null;
  toast("已删除");
  navigate({ scene: "app", nav: "playlists", detail: null });
}

function addTracks(id) {
  const playlist = playlistById(id);
  if (!playlist) return;
  playlist.tracks = TRACKS.map((track) => track.id);
  playlist.sub = `${playlist.tracks.length} 首`;
  toast("已添加曲目");
  render();
}

function toggleEmpty() {
  state.query = "";
  const input = $("q");
  if (input) input.value = "";
  returnTo = null;
  state.renaming = null;
  if (state.libraryEmpty) navigate({ scene: "app", libraryEmpty: false });
  else navigate({ scene: "app", libraryEmpty: true, nav: "library", detail: null });
}

function restoreLibrary() {
  state.libraryEmpty = false;
  toast("已添加 ~/Music");
  history.replaceState(history.state, "", hashFor());
  render();
}

function progressParts() {
  const track = shownTrack();
  if (!track) return { pos: "0:00", dur: "0:00", pct: "0%" };
  const ratio = track.duration ? Math.min(1, Math.max(0, state.position / track.duration)) : 0;
  return { pos: fmt(state.position), dur: fmt(track.duration), pct: `${ratio * 100}%` };
}

const ICONS = {
  play: '<polygon points="6 3 20 12 6 21 6 3"/>',
  pause: '<rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/>',
  "skip-back": '<polygon points="19 20 9 12 19 4 19 20"/><line x1="5" x2="5" y1="19" y2="5"/>',
  "skip-forward": '<polygon points="5 4 15 12 5 20 5 4"/><line x1="19" x2="19" y1="5" y2="19"/>',
  shuffle: '<path d="m18 14 4 4-4 4"/><path d="m18 2 4 4-4 4"/><path d="M2 18h1.973a4 4 0 0 0 3.3-1.7l5.454-8.6a4 4 0 0 1 3.3-1.7H22"/><path d="M2 6h1.972a4 4 0 0 1 3.6 2.2"/><path d="M22 18h-6.041a4 4 0 0 1-3.3-1.8l-.359-.45"/>',
  repeat: '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  "repeat-1": '<path d="m17 2 4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/><path d="M11 10h1v4"/>',
  "volume-2": '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>',
  "volume-x": '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="22" x2="16" y1="9" y2="15"/><line x1="16" x2="22" y1="9" y2="15"/>',
  "list-music": '<path d="M21 15V6"/><path d="M18.5 18a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z"/><path d="M12 12H3"/><path d="M16 6H3"/><path d="M12 18H3"/>',
  "list-plus": '<path d="M11 12H3"/><path d="M16 6H3"/><path d="M16 18H3"/><path d="M18 9v6"/><path d="M21 12h-6"/>',
  plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  pencil: '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/><path d="m15 5 4 4"/>',
  "chevron-left": '<path d="m15 18-6-6 6-6"/>',
  music: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
  disc: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="2"/>',
  ellipsis: '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
  "chevron-right": '<path d="m9 18 6-6-6-6"/>',
};

function icon(name, extra) {
  const cls = extra ? `ico ${extra}` : "ico";
  return `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
}

function playGlyph(playing) {
  return playing ? icon("pause") : icon("play", "nudge");
}

function eqHTML(active) {
  if (!active) return "";
  const live = state.playing ? " live" : "";
  return `<span class="eq${live}"><i></i><i></i><i></i><i></i></span>`;
}

function coverStyle(key) {
  let hash = 0;
  const text = String(key || "lyria");
  for (let index = 0; index < text.length; index += 1) hash = (hash * 33 + text.charCodeAt(index)) >>> 0;
  const hue = hash % 360;
  return `background:linear-gradient(145deg, hsl(${hue} 58% 58%), hsl(${(hue + 32) % 360} 46% 34%))`;
}

function trackRow(track) {
  const current = track.id === state.nowId && !isIdle();
  const selected = track.id === state.selectedId && !current;
  return `<div class="row track${current ? " active" : ""}${selected ? " selected" : ""}" data-track="${track.id}">
    <div class="title-cell">
      <button type="button" class="cover-btn" data-action="row-play" data-id="${track.id}" aria-label="${current && state.playing ? "暂停" : "播放"} ${esc(track.cn)}" style="${coverStyle(track.albumId)}">
        ${current ? `<span class="cover-eq">${eqHTML(true)}</span>` : ""}
        <span class="cover-play">${current && state.playing ? icon("pause") : icon("play")}</span>
      </button>
      <div class="title-stack"><div class="cn">${esc(track.cn)}</div></div>
    </div>
    <button type="button" class="meta" data-action="open-artist" data-id="${track.artistId}">${esc(track.artist)}</button>
    <button type="button" class="meta" data-action="open-album" data-id="${track.albumId}">${esc(track.album)}</button>
    <div class="row-end">
      <span class="meta dur">${fmt(track.duration)}</span>
      <button type="button" class="more" data-action="row-menu" data-id="${track.id}" aria-label="更多操作" aria-expanded="${state.menu && state.menu.trackId === track.id ? "true" : "false"}">${icon("ellipsis")}</button>
    </div>
  </div>`;
}

function trackTable(tracks) {
  const header = `<div class="row header"><div class="title-cell"><span class="cover-gap"></span><span>标题</span></div><div>艺人</div><div>专辑</div><div class="row-end"><span class="dur">时长</span><span class="more-gap"></span></div></div>`;
  return header + tracks.map(trackRow).join("");
}

function albumCard(album, subtitle) {
  return `<button type="button" class="card" data-action="open-album" data-id="${album.id}"><div class="art" style="${coverStyle(album.id)}"></div><div class="body"><div class="name">${esc(album.name)}</div><div class="sub">${esc(subtitle)}</div></div></button>`;
}

function artistCard(artist) {
  const count = tracksOfArtist(artist.id).length;
  const sub = count ? `${count} 首` : artist.count;
  return `<button type="button" class="card" data-action="open-artist" data-id="${artist.id}"><div class="art" style="border-radius:50%;margin:16px auto;width:70%;aspect-ratio:1;${coverStyle(artist.id)}"></div><div class="body" style="text-align:center"><div class="name">${esc(artist.name)}</div><div class="sub">${esc(sub)}</div></div></button>`;
}

function emptyBlock(title, copy, extra) {
  return `<div class="empty">${extra || ""}<h2>${esc(title)}</h2>${copy ? `<p>${esc(copy)}</p>` : ""}</div>`;
}

function searchEmptyHTML(query) {
  return emptyBlock("无搜索结果", `找不到与「${query}」匹配的音乐、艺人或专辑。`);
}

function emptyLibraryHTML() {
  return `<div class="empty">
    <div class="empty-mark">${icon("disc")}</div>
    <h2>曲库为空</h2>
    <p>添加本地音乐文件夹后，Lyria 会扫描并建立指纹索引。</p>
    <button type="button" class="btn primary" data-action="restore-library" style="margin-top:8px">添加曲库路径…</button>
  </div>`;
}

function libraryHTML(tracks) {
  return trackTable(tracks);
}

function detailActions(ids) {
  const joined = ids.join(",");
  return `<div class="actions">
    <button type="button" class="btn primary" data-action="play-ids" data-mode="play" data-ids="${joined}">${icon("play", "nudge")} 全部播放</button>
    <button type="button" class="btn" data-action="play-ids" data-mode="shuffle" data-ids="${joined}">${icon("shuffle")} 随机播放</button>
  </div>`;
}

function artistDetailHTML(artist) {
  const albums = albumsOf(artist.id);
  const tracks = tracksOfArtist(artist.id);
  const albumCount = albums.length;
  const trackCount = tracks.length;
  const albumGrid = albums.length
    ? `<div class="section-label">专辑</div><div class="grid" style="grid-template-columns:repeat(3,1fr);margin-bottom:16px">${albums.map((album) => albumCard(album, album.year)).join("")}</div>`
    : "";
  const trackBlock = tracks.length
    ? `<div class="section-label">热门曲目</div>${trackTable(tracks)}`
    : `<div class="empty" style="height:180px"><h2>还没有曲目</h2></div>`;
  return `<div class="hero">
      <div class="big-art" style="border-radius:50%"></div>
      <div class="info">
        <h1>${esc(artist.name)}</h1>
        <div class="sub">${albumCount} 张专辑 · ${trackCount} 首曲目</div>
        ${detailActions(tracks.map((track) => track.id))}
      </div>
    </div>
    ${albumGrid}${trackBlock}`;
}

function albumDetailHTML(album) {
  const tracks = tracksOfAlbum(album);
  const count = `${tracks.length} 首`;
  const rows = tracks.length ? trackTable(tracks) : `<div class="empty" style="height:180px"><h2>还没有曲目</h2></div>`;
  const ids = tracks.map((track) => track.id).join(",");
  return `<div class="hero">
      <div class="big-art"></div>
      <div class="info">
        <h1>${esc(album.name)}</h1>
        <div class="sub"><button type="button" class="link" data-action="open-artist" data-id="${album.artistId}">${esc(album.artist)}</button> · ${esc(album.year)} · ${esc(count)}</div>
        <div class="actions">
          <button type="button" class="btn primary" data-action="play-ids" data-mode="play" data-ids="${ids}">${icon("play", "nudge")} 全部播放</button>
          <button type="button" class="btn" data-action="play-ids" data-mode="shuffle" data-ids="${ids}">${icon("shuffle")} 随机</button>
          <button type="button" class="btn" data-action="play-ids" data-mode="enqueue" data-ids="${ids}">${icon("list-plus")} 加入队列</button>
        </div>
      </div>
    </div>
    ${rows}`;
}

function playlistSubtitle(playlist, tracks) {
  if (playlist.showcase) return "18 首 · 约 1 小时 12 分";
  if (!tracks.length) return "0 首";
  const minutes = Math.max(1, Math.round(tracks.reduce((sum, track) => sum + track.duration, 0) / 60));
  return `${tracks.length} 首 · 约 ${minutes} 分`;
}

function playlistDetailHTML(playlist) {
  const tracks = tracksOfPlaylist(playlist);
  const ids = tracks.map((track) => track.id).join(",");
  const title = state.renaming === playlist.id
    ? `<input id="rename" class="rename" value="${esc(playlist.name)}" aria-label="播放列表名称">`
    : `<h1>${esc(playlist.name)}</h1>`;
  if (!tracks.length) {
    return `<div class="hero">
        <div class="big-art" style="background:rgba(255,255,255,.06)"></div>
        <div class="info">
          ${title}
          <div class="sub">0 首</div>
          <div class="actions">
            <button type="button" class="btn primary" data-action="add-tracks" data-id="${playlist.id}">添加曲目…</button>
            <button type="button" class="btn" data-action="edit-playlist" data-id="${playlist.id}">${icon("pencil")} 编辑</button>
          </div>
        </div>
      </div>
      <div class="empty" style="height:220px">
        <h2>还没有曲目</h2>
        <p>从曲库把喜欢的歌拖进来，或点「添加曲目」。</p>
      </div>`;
  }
  return `<div class="hero">
      <div class="big-art"></div>
      <div class="info">
        ${title}
        <div class="sub">${esc(playlistSubtitle(playlist, tracks))}</div>
        <div class="actions">
          <button type="button" class="btn primary" data-action="play-ids" data-mode="play" data-ids="${ids}">${icon("play", "nudge")} 全部播放</button>
          <button type="button" class="btn" data-action="play-ids" data-mode="shuffle" data-ids="${ids}">${icon("shuffle")} 随机</button>
          <button type="button" class="btn" data-action="edit-playlist" data-id="${playlist.id}">${icon("pencil")} 编辑</button>
          <button type="button" class="btn danger" data-action="delete-playlist" data-id="${playlist.id}">删除</button>
        </div>
      </div>
    </div>
    ${trackTable(tracks)}`;
}

function detailHTML() {
  const { type, id } = state.detail;
  if (type === "artist") {
    const artist = artistById(id);
    return artist ? artistDetailHTML(artist) : emptyBlock("找不到艺人", "这个艺人卡片不在样例数据里。");
  }
  if (type === "album") {
    const album = albumById(id);
    return album ? albumDetailHTML(album) : emptyBlock("找不到专辑", "这个专辑卡片不在样例数据里。");
  }
  const playlist = playlistById(id);
  return playlist ? playlistDetailHTML(playlist) : emptyBlock("找不到播放列表", "这个播放列表已经删除。");
}

function settingsHTML() {
  const manage = state.manageOpen
    ? `<div class="mini-pop"><button type="button" data-action="${state.libraryEmpty ? "restore-library" : "preview-empty"}">${state.libraryEmpty ? "恢复示例曲库" : "查看空曲库"}</button></div>`
    : "";
  return `<div class="settings">
    <div class="setting"><div class="l"><div class="n">曲库路径</div><div class="d">~/Music/Lyria · 添加 / 移除文件夹后自动扫描</div></div><button type="button" class="btn" data-action="manage">管理…</button>${manage}</div>
    <div class="setting"><div class="l"><div class="n">重新扫描曲库</div><div class="d">按路径指纹重建索引，不改动文件</div></div><button type="button" class="btn" data-action="scan">${state.scanning ? "正在扫描…" : "立即扫描"}</button></div>
    <div class="setting"><div class="l"><div class="n">本地 HTTP API</div><div class="d">可选，默认关闭 · 端口 17890</div></div><button type="button" class="toggle${state.httpOn ? "" : " off"}" data-action="toggle-http" aria-pressed="${state.httpOn}" aria-label="本地 HTTP API"></button></div>
    <div class="setting"><div class="l"><div class="n">登录时启动</div><div class="d">开机后以菜单栏形态待命</div></div><button type="button" class="toggle${state.launchOn ? "" : " off"}" data-action="toggle-launch" aria-pressed="${state.launchOn}" aria-label="登录时启动"></button></div>
    <div class="setting"><div class="l"><div class="n">外观 · Deep Space</div><div class="d">左右栏同色深空底，无壁纸吸色 vibrancy</div></div><div class="btn">当前主题</div></div>
    <div class="setting danger"><div class="l"><div class="n">清除指纹缓存</div><div class="d">危险操作 · 下次打开将全量重建 trk_ 索引</div></div><button type="button" class="btn danger" data-action="clear-cache">清除</button></div>
  </div>`;
}

function panelHTML() {
  if (state.detail && !state.query.trim()) return detailHTML();
  if (state.query.trim()) {
    const matches = TRACKS.filter((track) => isListed(track.id) && matchTrack(track, state.query.trim()));
    return matches.length ? libraryHTML(matches) : searchEmptyHTML(state.query.trim());
  }
  if (state.nav === "settings") return settingsHTML();
  if (state.nav === "library" && state.libraryEmpty) return emptyLibraryHTML();
  if (state.nav === "library") {
    const tracks = TRACKS.filter((track) => isListed(track.id));
    return tracks.length ? libraryHTML(tracks) : emptyBlock("没有曲目", "曲库里的曲目都已移除。文件仍留在磁盘上。");
  }
  if (state.nav === "artists") return `<div class="grid">${ARTISTS.map(artistCard).join("")}</div>`;
  if (state.nav === "albums") return `<div class="grid">${ALBUMS.map((album) => albumCard(album, album.artist)).join("")}</div>`;
  if (state.nav === "playlists") {
    const create = `<button type="button" class="card" data-action="create-playlist" style="border-style:dashed;display:flex;align-items:center;justify-content:center;min-height:180px"><div class="body" style="text-align:center"><div class="name plus-mark">${icon("plus")}</div><div class="name">新建播放列表</div></div></button>`;
    const cards = state.playlists.map((playlist) => `<button type="button" class="card" data-action="open-playlist" data-id="${playlist.id}"><div class="art"></div><div class="body"><div class="name">${esc(playlist.name)}</div><div class="sub">${esc(playlist.sub)}</div></div></button>`).join("");
    return `<div class="grid">${create}${cards}</div>`;
  }
  return "";
}

function transportHTML() {
  const track = shownTrack();
  const progress = progressParts();
  const playing = state.playing && !!track;
  return `<div class="transport">
    <div class="np"><div class="cover" style="${track ? coverStyle(track.albumId) : ""}"></div><div><div class="t">${track ? esc(track.cn) : "—"}</div><div class="a">${track ? esc(track.artist) : "—"}</div></div></div>
    <div class="controls">
      <div class="prog">
        <span class="js-pos">${progress.pos}</span>
        <div class="bar" data-slider="progress"><div class="fill js-fill" style="width:${progress.pct}"></div><div class="knob js-knob" style="left:${progress.pct}"></div></div>
        <span class="js-dur">${progress.dur}</span>
      </div>
      <div class="btns">
        <button type="button" class="glyph${state.shuffle ? " on" : ""}" data-action="shuffle" title="随机播放">${icon("shuffle")}</button>
        <button type="button" class="glyph" data-action="prev" title="上一首">${icon("skip-back")}</button>
        <button type="button" class="play" data-action="toggle" title="${playing ? "暂停" : "播放"}">${playGlyph(playing)}</button>
        <button type="button" class="glyph" data-action="next" title="下一首">${icon("skip-forward")}</button>
        <button type="button" class="glyph${state.repeat === "off" ? "" : " on"}" data-action="repeat" title="${state.repeat === "one" ? "单曲循环" : state.repeat === "all" ? "重复全部" : "重复关闭"}">${icon(state.repeat === "one" ? "repeat-1" : "repeat")}</button>
      </div>
    </div>
    <div class="vol">
      <button type="button" class="glyph${state.queueOpen ? " on" : ""}" data-action="queue" title="队列" aria-pressed="${state.queueOpen}">${icon("list-music")}</button>
      <button type="button" class="glyph js-vol-ico" data-action="mute" title="音量">${icon(state.volume === 0 ? "volume-x" : "volume-2")}</button>
      <div class="slider" data-slider="volume"><div class="fill js-vol" style="width:${state.volume * 100}%"></div></div>
    </div>
  </div>`;
}

function queueHTML() {
  const items = state.queue.map(trackById).filter(Boolean);
  const rows = items.map((track) => `<button type="button" class="q-item${track.id === state.nowId ? " current" : ""}" data-track="${track.id}"><div class="cover"></div><div class="q-meta"><div class="q-title">${esc(track.cn)}</div><div class="q-artist">${esc(track.artist)}</div></div><div class="q-time">${fmt(track.duration)}</div></button>`).join("");
  return `<div class="q-head"><strong>队列</strong><span>${items.length} 首</span></div><div class="q-list">${rows || '<div class="empty" style="height:auto"><p>队列是空的</p></div>'}</div>`;
}

function upcomingHTML() {
  const ids = state.queue.filter((id) => trackById(id));
  const index = ids.indexOf(state.nowId);
  const rest = index >= 0 ? ids.slice(index + 1).concat(ids.slice(0, Math.max(index, 0))) : ids;
  return rest.filter((id) => id !== state.nowId).slice(0, 3).map((id) => {
    const track = trackById(id);
    return `<button type="button" class="upnext" data-track="${track.id}">${esc(track.cn)} · ${esc(track.artist)}</button>`;
  }).join("") || '<div class="upnext" style="color:var(--text3)">队列里没有下一首</div>';
}

function paintTimes() {
  const progress = progressParts();
  document.querySelectorAll(".js-pos").forEach((node) => { node.textContent = progress.pos; });
  document.querySelectorAll(".js-dur").forEach((node) => { node.textContent = progress.dur; });
  document.querySelectorAll(".js-fill").forEach((node) => { node.style.width = progress.pct; });
  document.querySelectorAll(".js-knob").forEach((node) => { node.style.left = progress.pct; });
  document.querySelectorAll(".js-vol").forEach((node) => { node.style.width = `${state.volume * 100}%`; });
  document.querySelectorAll(".js-vol-ico").forEach((node) => {
    node.innerHTML = icon(state.volume === 0 ? "volume-x" : "volume-2");
  });
}

function paintMenubar() {
  const track = shownTrack();
  document.querySelectorAll(".js-np-title").forEach((node) => { node.textContent = track ? track.cn : "—"; });
  document.querySelectorAll(".js-np-artist").forEach((node) => { node.textContent = track ? track.artist : "—"; });
  const play = $("menuPlay");
  if (play) {
    const playing = state.playing && !!track;
    play.innerHTML = playGlyph(playing);
    play.title = playing ? "暂停" : "播放";
  }
  const upnext = $("upnext");
  if (upnext) upnext.innerHTML = upcomingHTML();
}

function paintChrome() {
  $("window").classList.toggle("is-hidden", state.scene !== "app");
  $("menubarStage").classList.toggle("is-hidden", state.scene !== "menubar");
  $("annotStage").classList.toggle("is-hidden", state.scene !== "chrome");
  document.querySelectorAll("button.nav-item").forEach((button) => {
    button.classList.toggle("active", state.scene === "app" && button.dataset.nav === state.nav);
  });
  $("emptyBtn").classList.toggle("on", state.libraryEmpty && state.scene === "app");
  $("menuBtn").classList.toggle("on", state.scene === "menubar");
  $("chromeBtn").classList.toggle("on", state.scene === "chrome");
  $("clearQ").classList.toggle("is-hidden", !state.query);
  const titles = { library: "曲库", artists: "艺人", albums: "专辑", playlists: "播放列表", settings: "设置" };
  const heading = $("pageTitle");
  const meta = $("pageMeta");
  const back = $("navBack");
  if (back) {
    const searching = !!state.query.trim();
    back.classList.toggle("is-hidden", !(state.detail || searching));
    back.setAttribute("aria-label", "返回");
  }
  if (heading && meta) {
    let title = titles[state.nav] || "曲库";
    let note = "";
    if (state.query.trim()) {
      const count = TRACKS.filter((track) => isListed(track.id) && matchTrack(track, state.query.trim())).length;
      title = "搜索";
      note = count ? `${count} 首` : "无结果";
    } else if (state.nav === "library" && !state.detail && !state.libraryEmpty) {
      note = `${TRACKS.filter((track) => isListed(track.id)).length} 首`;
    }
    heading.textContent = title;
    meta.textContent = note;
  }
  if (state.scene === "menubar") document.title = "Lyria · 菜单栏";
  else if (state.scene === "chrome") document.title = "Lyria · 窗口约定";
  else if (state.detail?.type === "artist") document.title = `Lyria · ${artistById(state.detail.id)?.name || "艺人"}`;
  else if (state.detail?.type === "album") document.title = `Lyria · ${albumById(state.detail.id)?.name || "专辑"}`;
  else if (state.detail?.type === "playlist") document.title = `Lyria · ${playlistById(state.detail.id)?.name || "播放列表"}`;
  else document.title = `Lyria · ${titles[state.nav] || "曲库"}`;
}

function render() {
  syncIdle();
  paintChrome();
  const panel = $("panel");
  const scroll = panel.scrollTop;
  panel.innerHTML = panelHTML();
  panel.scrollTop = scroll;
  $("transport").innerHTML = transportHTML();
  $("queue").innerHTML = queueHTML();
  $("queue").classList.toggle("is-hidden", !state.queueOpen || state.scene !== "app");
  paintMenubar();
  paintTimes();
  const toastNode = $("toast");
  toastNode.textContent = state.toast;
  toastNode.classList.toggle("show", !!state.toast);
  paintMenu();
  const rename = $("rename");
  if (rename && state.focusRename) {
    state.focusRename = false;
    rename.focus();
    const end = rename.value.length;
    rename.setSelectionRange(end, end);
  }
}

function paintMenu() {
  const host = $("rowMenu");
  if (!host) return;
  if (!state.menu) {
    host.innerHTML = "";
    document.querySelectorAll("button.more").forEach((button) => button.setAttribute("aria-expanded", "false"));
    return;
  }
  const track = trackById(state.menu.trackId);
  if (!track) {
    state.menu = null;
    host.innerHTML = "";
    return;
  }
  const playlistId = state.detail && state.detail.type === "playlist" ? state.detail.id : "";
  const playlistItems = state.playlists.map((playlist) => `<button type="button" data-action="menu-add-playlist" data-id="${track.id}" data-playlist="${playlist.id}">${esc(playlist.name)}</button>`).join("");
  const removePlaylist = playlistId
    ? `<button type="button" class="danger" data-action="menu-remove-playlist" data-id="${track.id}" data-playlist="${playlistId}">从播放列表移除</button>`
    : "";
  host.innerHTML = `<div class="row-menu" style="left:${state.menu.x}px;top:${state.menu.y}px">
    <button type="button" data-action="row-play" data-id="${track.id}">${icon("play")} 播放</button>
    <button type="button" data-action="menu-next" data-id="${track.id}">${icon("skip-forward")} 下一首播放</button>
    <button type="button" data-action="menu-queue" data-id="${track.id}">${icon("list-plus")} 加入队列</button>
    <div class="menu-branch">
      <button type="button">${icon("list-music")} 加入播放列表 ${icon("chevron-right")}</button>
      <div class="menu-sub">${playlistItems}</div>
    </div>
    <button type="button" data-action="open-artist" data-id="${track.artistId}">前往艺人</button>
    <button type="button" data-action="open-album" data-id="${track.albumId}">前往专辑</button>
    <div class="menu-sep"></div>
    ${removePlaylist}
    <button type="button" class="danger" data-action="menu-remove-library" data-id="${track.id}">从曲库移除</button>
  </div>`;
  const menu = host.querySelector(".row-menu");
  const rect = menu.getBoundingClientRect();
  let left = state.menu.align === "start" ? state.menu.x : state.menu.x - rect.width;
  let top = state.menu.y;
  if (left < 8) left = 8;
  if (left + rect.width > window.innerWidth - 8) left = window.innerWidth - rect.width - 8;
  if (top + rect.height > window.innerHeight - 8) top = Math.max(8, state.menu.y - rect.height - 28);
  menu.style.left = `${left}px`;
  menu.style.top = `${top}px`;
  const openId = state.menu && state.menu.trackId;
  document.querySelectorAll("button.more").forEach((button) => {
    button.setAttribute("aria-expanded", button.dataset.id === openId ? "true" : "false");
  });
}

function openRowMenu(trackId, x, y, align) {
  state.menu = { trackId, x, y, align };
  paintMenu();
}

function selectTrack(id) {
  state.selectedId = id;
  document.querySelectorAll(".row.track").forEach((row) => {
    const on = row.dataset.track === id && row.dataset.track !== state.nowId;
    row.classList.toggle("selected", on);
  });
}

function handleAction(el) {
  const action = el.dataset.action;
  if (action === "row-play") {
    if (el.dataset.id === state.nowId) togglePlay();
    else playTrack(el.dataset.id);
  }
  else if (action === "row-menu") {
    if (state.menu && state.menu.trackId === el.dataset.id) {
      state.menu = null;
      paintMenu();
      return;
    }
    const rect = el.getBoundingClientRect();
    openRowMenu(el.dataset.id, rect.right, rect.bottom + 6, "end");
  } else if (action === "menu-next") playNext(el.dataset.id);
  else if (action === "menu-queue") addToQueue([el.dataset.id]);
  else if (action === "menu-add-playlist") addTrackToPlaylist(el.dataset.playlist, el.dataset.id);
  else if (action === "menu-remove-playlist") removeFromPlaylist(el.dataset.playlist, el.dataset.id);
  else if (action === "menu-remove-library") {
    const track = trackById(el.dataset.id);
    const name = track ? track.cn : "这首歌";
    if (confirm(`从曲库移除「${name}」？文件仍会留在磁盘上。`)) removeFromLibrary(el.dataset.id);
    else {
      state.menu = null;
      paintMenu();
    }
  } else if (action === "open-artist") openDetail("artist", el.dataset.id);
  else if (action === "open-album") openDetail("album", el.dataset.id);
  else if (action === "open-playlist") openDetail("playlist", el.dataset.id);
  else if (action === "back" || action === "nav-back") {
    if (state.query.trim()) onSearch("");
    else goBack();
  }
  else if (action === "play-ids") {
    const ids = (el.dataset.ids || "").split(",").filter(Boolean);
    if (el.dataset.mode === "enqueue") addToQueue(ids);
    else playIds(ids, el.dataset.mode === "shuffle");
  } else if (action === "toggle") togglePlay();
  else if (action === "next") goNext(true);
  else if (action === "prev") goPrev();
  else if (action === "shuffle") {
    state.shuffle = !state.shuffle;
    render();
  } else if (action === "repeat") cycleRepeat();
  else if (action === "queue") {
    state.queueOpen = !state.queueOpen;
    render();
  } else if (action === "mute") {
    if (state.volume > 0) {
      state.prevVol = state.volume;
      state.volume = 0;
    } else state.volume = state.prevVol || 0.6;
    render();
  } else if (action === "clear-search") {
    const input = $("q");
    if (input) input.value = "";
    onSearch("");
  } else if (action === "create-playlist") createPlaylist();
  else if (action === "add-tracks") addTracks(el.dataset.id);
  else if (action === "edit-playlist") {
    const playlist = playlistById(el.dataset.id);
    renameOrigin = playlist ? playlist.name : "";
    state.renaming = el.dataset.id;
    state.focusRename = true;
    render();
  } else if (action === "delete-playlist") deletePlaylist(el.dataset.id);
  else if (action === "toggle-http") {
    state.httpOn = !state.httpOn;
    toast(state.httpOn ? "已开启本地 HTTP · 17890" : "已关闭本地 HTTP");
    render();
  } else if (action === "toggle-launch") {
    state.launchOn = !state.launchOn;
    toast(state.launchOn ? "已设置登录时启动" : "已关闭登录时启动");
    render();
  } else if (action === "manage") {
    state.manageOpen = !state.manageOpen;
    render();
  } else if (action === "preview-empty") toggleEmpty();
  else if (action === "scan") {
    if (state.scanning) return;
    state.scanning = true;
    state.manageOpen = false;
    render();
    setTimeout(() => {
      state.scanning = false;
      toast("扫描完成");
      render();
    }, 900);
  } else if (action === "clear-cache") {
    if (confirm("清除指纹缓存？旧 id 全部失效，下次打开将全量重建。")) {
      toast("已清除指纹缓存");
      render();
    }
  } else if (action === "restore-library") {
    state.manageOpen = false;
    restoreLibrary();
  } else if (action === "toggle-empty") toggleEmpty();
  else if (action === "scene-menubar") {
    navigate({ scene: state.scene === "menubar" ? "app" : "menubar" });
  } else if (action === "scene-chrome") {
    navigate({ scene: state.scene === "chrome" ? "app" : "chrome" });
  }
}

function applySlider(slider, event) {
  const rect = slider.getBoundingClientRect();
  if (!rect.width) return;
  const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
  if (slider.dataset.slider === "volume") {
    state.volume = ratio;
    if (ratio > 0) state.prevVol = ratio;
  } else {
    const track = shownTrack();
    if (!track) return;
    state.position = ratio * track.duration;
  }
  paintTimes();
}

document.body.addEventListener("click", (event) => {
  const actionEl = event.target.closest("[data-action]");
  if (actionEl) {
    handleAction(actionEl);
    return;
  }
  const row = event.target.closest(".row.track");
  if (row) {
    selectTrack(row.dataset.track);
    return;
  }
  const trackEl = event.target.closest("[data-track]");
  if (trackEl) {
    playTrack(trackEl.dataset.track);
    return;
  }
  const navEl = event.target.closest("[data-nav]");
  if (navEl) selectNav(navEl.dataset.nav);
});

document.body.addEventListener("dblclick", (event) => {
  const row = event.target.closest(".row.track");
  if (!row || event.target.closest("[data-action]")) return;
  playTrack(row.dataset.track);
});

document.body.addEventListener("contextmenu", (event) => {
  const row = event.target.closest(".row.track");
  if (!row) return;
  event.preventDefault();
  openRowMenu(row.dataset.track, event.clientX, event.clientY, "start");
});

document.addEventListener("pointerdown", (event) => {
  if (state.menu && !event.target.closest(".row-menu") && !event.target.closest('[data-action="row-menu"]')) {
    state.menu = null;
    paintMenu();
  }
  if (state.manageOpen && !event.target.closest(".mini-pop") && !event.target.closest('[data-action="manage"]')) {
    state.manageOpen = false;
    render();
  }
  const slider = event.target.closest("[data-slider]");
  if (!slider) return;
  dragging = slider;
  if (slider.setPointerCapture) slider.setPointerCapture(event.pointerId);
  applySlider(slider, event);
});

document.addEventListener("pointermove", (event) => {
  if (!dragging) return;
  applySlider(dragging, event);
});

function endDrag() { dragging = null; }
document.addEventListener("pointerup", endDrag);
document.addEventListener("pointercancel", endDrag);

document.addEventListener("focusout", (event) => {
  if (event.target.id !== "rename") return;
  const value = event.target.value;
  setTimeout(() => {
    if (document.activeElement && document.activeElement.id === "rename") return;
    commitRename(value);
  }, 0);
});

document.addEventListener("keydown", (event) => {
  const typing = event.target.matches("input, textarea");
  if (event.key === "Escape") {
    if (state.menu) {
      state.menu = null;
      paintMenu();
      return;
    }
    if (state.renaming) {
      state.renaming = null;
      render();
      return;
    }
    if (state.manageOpen) {
      state.manageOpen = false;
      render();
      return;
    }
    if (state.queueOpen && state.scene === "app") {
      state.queueOpen = false;
      render();
      return;
    }
    if (state.query) {
      const input = $("q");
      if (input) input.value = "";
      onSearch("");
    }
    return;
  }
  if (typing) {
    if (event.target.id === "rename" && event.key === "Enter") {
      event.preventDefault();
      commitRename(event.target.value);
    }
    return;
  }
  if (event.key === " ") {
    event.preventDefault();
    togglePlay();
  } else if (event.key === "ArrowRight") seekBy(5);
  else if (event.key === "ArrowLeft") seekBy(-5);
});

$("q").addEventListener("input", (event) => onSearch(event.target.value));

document.addEventListener("input", (event) => {
  if (event.target.id !== "rename" || !state.renaming) return;
  const playlist = playlistById(state.renaming);
  if (playlist) playlist.name = event.target.value;
});

window.addEventListener("popstate", () => {
  state.query = "";
  const input = $("q");
  if (input) input.value = "";
  returnTo = null;
  state.renaming = null;
  state.manageOpen = false;
  applyHash();
  render();
});

setInterval(() => {
  if (!state.playing || dragging) return;
  const track = shownTrack();
  if (!track) return;
  state.position += 0.25;
  if (state.position >= track.duration) {
    state.position = track.duration;
    goNext(false);
    return;
  }
  paintTimes();
}, 250);

applyHash();
history.replaceState({ lyria: seq }, "", hashFor());
render();
