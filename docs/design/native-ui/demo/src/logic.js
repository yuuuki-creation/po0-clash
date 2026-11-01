const PLATFORM = '__PLATFORM__';
const NARROW = PLATFORM === 'win' ? '(max-width: 1007px)' : '(max-width: 759px)';
const ICONS = {
  pane: 'M4 6h16M4 12h16M4 18h16',
  sidebar: 'M4 5h16v14H4zM9 5v14',
  back: 'M15 5l-7 7 7 7',
  refresh: 'M20 11a8 8 0 1 0-2.3 6M20 5v6h-6',
  more: 'M12 5h.01M12 12h.01M12 19h.01',
  moreH: 'M5 12h.01M12 12h.01M19 12h.01',
  min: 'M5 12h14',
  max: 'M6 6h12v12H6z',
  close: 'M6 6l12 12M18 6 6 18',
  down: 'M12 5v14M7 14l5 5 5-5',
  up: 'M12 19V5M7 10l5-5 5 5',
  search: 'M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14ZM20 20l-4-4',
  trash: 'M4 7h16M9 7V4h6v3M6.5 7l1 13h9l1-13',
  chevron: 'M9 5l7 7-7 7',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  plus: 'M12 5v14M5 12h14',
  bolt: 'M13 3 5 14h6l-1 7 8-11h-6l1-7Z',
  chevDown: 'M6 9l6 6 6-6',
  locate: 'M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0-8ZM12 3v3M12 18v3M3 12h3M18 12h3',
};
const PAGES = [
  ['home', '仪表盘', 'M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z'],
  ['proxies', '代理', 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18ZM3 12h18M12 3c3 3 3.5 6 3.5 9s-.5 6-3.5 9c-3-3-3.5-6-3.5-9s.5-6 3.5-9Z'],
  ['profiles', '配置', 'M12 3 3 8l9 5 9-5-9-5ZM3 13l9 5 9-5M3 18l9 5 9-5'],
  ['whitelist', '加白', 'M12 3l8 3v6c0 4.5-3.2 7.6-8 9-4.8-1.4-8-4.5-8-9V6l8-3ZM8.5 12l2.5 2.5 4.5-5'],
  ['activity', '活动', 'M3 12h4l3-8 4 16 3-8h4'],
  ['tools', '工具', 'M4 7h9M17 7h3M4 17h3M11 17h9M13 5h4v4h-4zM7 15h4v4H7z'],
].filter(([id]) => PLATFORM !== 'and' || id !== 'activity');
const DELAYS = { '东京 03': 38, '东京 07': 46, '东京 11': 49, '大阪 02': 52, '大阪 05': 58, '香港 01': 64, '香港 05': 67, '香港 IEPL 02': 71, '台北 01': 83, '首尔 01': 88, '首尔 02': 91, '新加坡 02': 96, '新加坡 05': 104, '洛杉矶 04': 162, '洛杉矶 09': 168, '圣何塞 01': 171, '法兰克福 01': 612, '伦敦 03': 0 };
const ALL = Object.keys(DELAYS);
const KINDS = ['Trojan', 'Hysteria2', 'VLESS', 'Shadowsocks'];
const PICK = ['节点选择', '自动选择', '香港 01', '东京 03', '新加坡 02', '洛杉矶 04', 'DIRECT'];
const GROUPS = [
  ['节点选择', 'Selector', ['自动选择', 'DIRECT', ...ALL]],
  ['自动选择', 'URLTest', ALL.slice(0, 8)],
  ['故障转移', 'Fallback', ALL.slice(0, 5)],
  ['AI', 'Selector', ['新加坡 02', '东京 03', '洛杉矶 04', '圣何塞 01']],
  ['流媒体', 'Selector', ['香港 01', '香港 IEPL 02', '新加坡 02', '东京 07']],
  ...['Netflix', 'YouTube', 'Disney+', 'Spotify', 'Telegram', 'Discord', 'Twitter', 'GitHub', 'Google', 'Microsoft', 'Apple', 'Steam', 'PayPal'].map((name) => [name, 'Selector', PICK]),
  ['日本 IEPL 专线优选节点组（低倍率）', 'URLTest', ['东京 03', '东京 07', '东京 11', '大阪 02', '大阪 05']],
  ['哔哩哔哩', 'Selector', ['DIRECT', '香港 01', '台北 01']],
  ['巴哈姆特', 'Selector', ['台北 01', 'DIRECT']],
  ['广告拦截', 'Selector', ['REJECT', 'DIRECT']],
  ['国内直连', 'Selector', ['DIRECT', '节点选择']],
  ['漏网之鱼', 'Selector', ['节点选择', 'DIRECT']],
].map(([name, kind, nodes]) => ({ name, kind, nodes, auto: kind !== 'Selector' }));
const SORTS = [['profile', '默认排序'], ['delay', '按延迟'], ['name', '按名称']];
const PROFILES = [
  { id: 'a', name: '主力订阅', pct: '37%', used: '185 / 500 GB', until: '2026-12-31' },
  { id: 'b', name: '备用订阅', pct: '12%', used: '12 / 100 GB', until: '2027-03-18' },
  { id: 'c', name: '分享链接', pct: '', used: '6 个节点', until: '' },
];
const ENTRIES = [
  { id: 'a', kind: 'po0', name: '家里宽带', label: 'a8f3…91c2', state: 'applied' },
  { id: 'b', kind: 'po0', name: '公司', label: '7bd0…e41a', state: 'applied' },
  { id: 'c', kind: 'ggy', name: '备用线路', label: 'ggy.example/k2f…', state: 'applied' },
];
const CONN = [['api.github.com', 'DOMAIN-SUFFIX', '节点选择 › 东京 03', '1.2 MB'], ['www.google.com', 'GEOSITE', '节点选择 › 东京 03', '84 KB'], ['chatgpt.com', 'GEOSITE', 'AI › 新加坡 02', '3.6 MB'], ['i.ytimg.com', 'GEOSITE', '流媒体 › 香港 01', '18 MB'], ['registry.npmjs.org', 'MATCH', '节点选择 › 东京 03', '640 KB'], ['www.bilibili.com', 'GEOIP', '直连', '9.1 MB'], ['update.microsoft.com', 'GEOSITE', '直连', '220 KB'], ['cdn.discordapp.com', 'MATCH', '节点选择 › 东京 03', '1.0 MB'], ['github.com', 'DOMAIN-SUFFIX', '节点选择 › 东京 03', '410 KB'], ['open.spotify.com', 'GEOSITE', '流媒体 › 香港 01', '2.3 MB'], ['claude.ai', 'GEOSITE', 'AI › 新加坡 02', '760 KB']];
const LOGS = [['info', '[TCP] 127.0.0.1:52144 → api.github.com:443 using 节点选择[东京 03]'], ['info', '[TCP] 127.0.0.1:52151 → chatgpt.com:443 using AI[新加坡 02]'], ['info', '[UDP] 127.0.0.1:61022 → i.ytimg.com:443 using 流媒体[香港 01]'], ['warn', '[DNS] resolve cdn.example.invalid: no such host'], ['info', '[TCP] 127.0.0.1:52160 → www.bilibili.com:443 using DIRECT'], ['info', '[TCP] 127.0.0.1:52171 → registry.npmjs.org:443 using 节点选择[东京 03]'], ['info', '[Provider] 主力订阅 updated'], ['info', '[TCP] 127.0.0.1:52188 → www.google.com:443 using 节点选择[东京 03]'], ['info', '[TCP] 127.0.0.1:52194 → github.com:443 using 节点选择[东京 03]'], ['info', '[UDP] 127.0.0.1:61040 → open.spotify.com:443 using 流媒体[香港 01]'], ['info', '[TCP] 127.0.0.1:52203 → claude.ai:443 using AI[新加坡 02]']];
const APP_OPTIONS = [
  ['启动', [['autostart', '开机自启'], ['silent', '静默启动'], ['autoConnect', '自动连接'], ['tray', '关闭时最小化到托盘']]],
  ['界面', [['pageAnim', '页面切换动画'], ['navLabels', '导航显示文字'], ['logs', '日志捕获']]],
  ['网络', [['closeOnSwitch', '切换节点后断开连接'], ['checkCert', '校验订阅的 TLS 证书']]],
];
const LEN = 60;
const W = 480;
const H = 148;
const STEP = W / (LEN - 1);
const CLOSE_MS = PLATFORM === 'win' ? 90 : 210;

const rate = (bytes) => bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + ' MB/s' : bytes >= 1024 ? Math.round(bytes / 1024) + ' KB/s' : '0 B/s';
const delayText = (d) => d === undefined ? '—' : d === 0 ? '超时' : d + ' ms';
const rank = (d) => d === undefined ? 1e8 : d === 0 ? 1e9 : d;
const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.dn = [];
    this.up = [];
    let d = 0.45;
    let u = 0.15;
    for (let n = 0; n <= LEN; n++) {
      d = this.walk(d, 0.45, 0.2);
      u = this.walk(u, 0.15, 0.06);
      this.dn.push(d);
      this.up.push(u);
    }
    this.timers = [];
    this.nextId = 1;
    this.state = {
      page: 'home', drill: null, drillDir: '', on: true, starting: false, mode: 'rule', route: 'tun', group: '节点选择', query: '', searching: false, sort: 'profile', proxOpen: false, proxReturn: false, groupMenu: null,
      now: Object.fromEntries(GROUPS.map((g) => [g.name, { 节点选择: '东京 03', 自动选择: '东京 07', AI: '新加坡 02', 流媒体: '香港 01' }[g.name] ?? g.nodes[0]])),
      delays: DELAYS, waiting: {}, testing: false,
      profiles: PROFILES, profile: 'a', updating: {},
      wl: true, entries: ENTRIES, checking: false, leaving: {}, entering: {},
      activity: 'connections', theme: null, theming: false, conns: 128, pane: false,
      menu: null, menuClosing: false, dialog: null, dialogClosing: false, formText: '', formName: '',
      options: { autostart: true, silent: false, autoConnect: true, tray: true, pageAnim: true, navLabels: true, logs: true, closeOnSwitch: true, checkCert: true },
      scrolled: false,
    };
    this.setRoot = (el) => { this.root = el; };
    this.setSlide = (el) => { this.slideEl = el; this.draw(); };
    this.setDn = (el) => { this.dnEl = el; this.draw(); };
    this.setUp = (el) => { this.upEl = el; this.draw(); };
    this.focusIn = (el) => { if (el) el.focus(); };
    this.setGroupMenu = (el) => { if (el) el.querySelector('.sel')?.scrollIntoView({ block: 'nearest' }); };
    this.onScroll = (event) => {
      const scrolled = event.target.scrollTop > 0;
      if (scrolled !== this.state.scrolled) this.setState({ scrolled });
    };
    this.ripple = (event) => {
      if (PLATFORM !== 'and' || reduced()) return;
      const b = event.target.closest && event.target.closest('button');
      if (!b || b.classList.contains('switch') || b.classList.contains('tab') || b.classList.contains('scrim') || b.classList.contains('menu-scrim')) return;
      const r = b.getBoundingClientRect();
      b.style.setProperty('--rx', (event.clientX - r.left) + 'px');
      b.style.setProperty('--ry', (event.clientY - r.top) + 'px');
      b.animate(
        [{ opacity: 0.14, transform: 'translate(-50%, -50%) scale(0)' }, { opacity: 0, transform: 'translate(-50%, -50%) scale(1)' }],
        { duration: 450, easing: 'cubic-bezier(0.2, 0, 0, 1)', pseudoElement: '::after' },
      );
    };
  }

  later(ms, fn) {
    this.timers.push(setTimeout(fn, ms));
  }

  walk(v, mid, swing) {
    const next = v + (Math.random() - 0.5) * swing + (mid - v) * 0.1;
    return Math.min(0.9, Math.max(0.03, next));
  }

  componentDidMount() {
    this.timer = setInterval(() => this.tick(), 1000);
  }

  componentWillUnmount() {
    clearInterval(this.timer);
    this.timers.forEach(clearTimeout);
  }

  tick() {
    const on = this.state.on;
    this.dn.push(on ? this.walk(this.dn[LEN], 0.45, 0.2) : 0);
    this.up.push(on ? this.walk(this.up[LEN], 0.15, 0.06) : 0);
    this.dn.shift();
    this.up.shift();
    this.draw();
    if (this.slideEl) {
      const el = this.slideEl;
      el.style.transition = 'none';
      el.style.transform = 'translateX(0)';
      el.getBoundingClientRect();
      if (!reduced()) {
        el.style.transition = 'transform 1000ms linear';
        el.style.transform = 'translateX(' + (-STEP) + 'px)';
      }
    }
    this.setState({ conns: on ? Math.max(90, this.state.conns + Math.round((Math.random() - 0.5) * 7)) : this.state.conns });
  }

  line(series) {
    return series.map((v, n) => (n ? 'L' : 'M') + (n * STEP).toFixed(1) + ' ' + (H - 6 - v * (H - 16)).toFixed(1)).join('');
  }

  draw() {
    if (this.dnEl) this.dnEl.setAttribute('d', this.line(this.dn));
    if (this.upEl) this.upEl.setAttribute('d', this.line(this.up));
  }

  seg(list, value, set) {
    return {
      n: list.length,
      i: Math.max(0, list.findIndex(([id]) => id === value)),
      items: list.map(([id, label]) => ({ label, cls: id === value ? 'act' : '', go: () => set(id) })),
    };
  }

  closeDialog() {
    this.setState({ dialogClosing: true });
    this.later(CLOSE_MS, () => this.setState({ dialog: null, dialogClosing: false, formText: '', formName: '' }));
  }

  closeMenu() {
    this.setState({ menuClosing: true });
    this.later(100, () => this.setState({ menu: null, menuClosing: false }));
  }

  openMenu(event, extra) {
    const button = event.currentTarget.getBoundingClientRect();
    const root = this.root.getBoundingClientRect();
    this.setState({ menu: { ...extra, top: Math.min(button.bottom - root.top + 4, root.height - 240), right: root.right - button.right }, menuClosing: false });
  }

  closeGroupMenu() {
    this.setState({ menuClosing: true });
    this.later(100, () => this.setState({ groupMenu: null, menuClosing: false }));
  }

  reveal(smooth) {
    this.later(0, () => {
      if (!this.root) return;
      const behavior = smooth && !reduced() ? 'smooth' : 'auto';
      this.root.querySelectorAll('.group-pane .sel, .tbl .t-node.sel, .prox-nodes .sel').forEach((el) => el.scrollIntoView({ block: 'nearest', behavior }));
    });
  }

  updateProfile(id) {
    if (this.state.updating[id]) return;
    this.setState({ updating: { ...this.state.updating, [id]: true } });
    this.later(1000, () => {
      const updating = { ...this.state.updating };
      delete updating[id];
      this.setState({ updating });
    });
  }

  removeRow(key, id) {
    this.setState({ leaving: { ...this.state.leaving, [id]: true } });
    this.later(210, () => this.setState({ [key]: this.state[key].filter((row) => row.id !== id) }));
  }

  checkEntries(ids) {
    const entries = this.state.entries.map((e) => ids.includes(e.id) ? { ...e, state: 'checking' } : e);
    this.setState({ entries, checking: true });
    ids.forEach((id, n) => this.later(700 + n * 220, () => {
      this.setState({ entries: this.state.entries.map((e) => e.id === id ? { ...e, state: 'applied' } : e) });
    }));
    this.later(700 + ids.length * 220, () => this.setState({ checking: false }));
  }

  confirmDialog() {
    const { dialog, formText, formName } = this.state;
    if (dialog.type === 'add-wl') {
      const lines = formText.split('\n').map((l) => l.trim()).filter(Boolean);
      const added = lines.map((line) => ({ id: 'n' + this.nextId++, kind: line.includes('ggy') ? 'ggy' : 'po0', name: formName.trim() || '未命名', label: line.length > 18 ? line.slice(0, 8) + '…' + line.slice(-4) : line, state: 'checking' }));
      const entering = { ...this.state.entering };
      added.forEach((row) => { entering[row.id] = true; });
      this.setState({ entries: [...this.state.entries, ...added], entering });
      this.closeDialog();
      this.later(300, () => this.checkEntries(added.map((row) => row.id)));
    }
    if (dialog.type === 'add-profile') {
      const row = { id: 'n' + this.nextId++, name: formName.trim() || '新订阅', pct: '0%', used: '0 / 100 GB', until: '2027-06-30' };
      this.setState({ profiles: [...this.state.profiles, row], entering: { ...this.state.entering, [row.id]: true } });
      this.closeDialog();
    }
    if (dialog.type === 'remove-wl') {
      this.closeDialog();
      this.removeRow('entries', dialog.id);
    }
    if (dialog.type === 'remove-profile') {
      this.closeDialog();
      this.removeRow('profiles', dialog.id);
    }
  }

  renderVals() {
    const s = this.state;
    const go = (page) => () => {
      const narrow = PLATFORM !== 'and' && matchMedia(NARROW).matches;
      this.setState({ page, drill: null, drillDir: '', query: '', searching: false, scrolled: false, pane: narrow ? false : s.pane, proxOpen: false, proxReturn: false });
      if (page === 'proxies') this.reveal(false);
    };
    const theme = s.theme ?? this.props.theme ?? 'light';
    const node = s.now['节点选择'];
    const q = s.query.trim().toLowerCase();
    const hit = (text) => text.toLowerCase().includes(q);
    const shownGroups = GROUPS.filter((g) => !q || hit(g.name) || g.nodes.some(hit));
    const group = shownGroups.find((g) => g.name === s.group) ?? shownGroups[0] ?? GROUPS[0];
    const resolve = (name) => s.now[name] ? resolve(s.now[name]) : name;
    const delayOf = (name) => s.delays[resolve(name)];
    const locate = () => {
      this.setState({ query: '', group: '节点选择', proxOpen: true, proxReturn: false });
      this.reveal(true);
    };
    const selected = s.profiles.find((p) => p.id === s.profile) ?? s.profiles[0];
    const applied = s.wl ? s.entries.filter((e) => e.state === 'applied').length : 0;
    const dialog = s.dialog;
    const dialogTitle = !dialog ? '' : dialog.type === 'add-wl' ? '添加加白项' : dialog.type === 'add-profile' ? '添加订阅' : '移除「' + dialog.name + '」？';
    const pageIndex = PAGES.findIndex(([id]) => id === s.page);
    return {
      i: ICONS,
      rootRef: this.setRoot,
      onPointerDown: this.ripple,
      rootCls: theme + ' pal-' + (this.props.palette ?? 'b') + (s.pane ? ' pane-toggled' : '') + (s.theming ? ' theming' : '') + (s.options.pageAnim ? '' : ' no-page-anim'),
      togglePane: () => this.setState({ pane: !s.pane }),
      title: s.drill ? '应用' : PLATFORM === 'and' && s.page === 'proxies' && s.proxOpen ? group.name : PAGES[pageIndex][1],
      navI: pageIndex,
      tabs: PAGES.map(([id, label, icon]) => ({ label, icon, cls: id === s.page ? 'act' : '', go: go(id) })),
      navLabels: s.options.navLabels,
      isHome: s.page === 'home',
      isProxies: s.page === 'proxies',
      isProfiles: s.page === 'profiles',
      isWhitelist: s.page === 'whitelist',
      isActivity: s.page === 'activity',
      isToolsRoot: s.page === 'tools' && !s.drill,
      isDrill: !!s.drill,
      capCls: s.page === 'proxies' || s.page === 'activity' ? '' : 'capped',
      scrolledCls: s.scrolled ? 'scrolled' : '',
      onScroll: this.onScroll,
      back: () => this.setState({ drill: null, drillDir: 'back', scrolled: false }),
      toolsPageCls: 'page ' + s.drillDir,
      statusText: s.starting ? '正在连接…' : s.on ? '已连接' : '未连接',
      dotCls: s.on ? 'on' : s.starting ? 'wait' : '',
      starting: s.starting,
      toggle: () => {
        if (s.starting) return;
        if (s.on) return this.setState({ on: false });
        this.setState({ starting: true });
        this.later(1100, () => this.setState({ on: true, starting: false }));
      },
      powerCls: s.on ? '' : 'primary',
      powerLabel: s.starting ? '正在连接' : s.on ? '断开连接' : '连接',
      slideRef: this.setSlide,
      dnRef: this.setDn,
      upRef: this.setUp,
      nodeName: node,
      nodeDelay: delayText(delayOf(node)),
      dnText: rate(s.on ? this.dn[LEN] * 16 * 1048576 : 0),
      upText: rate(s.on ? this.up[LEN] * 6 * 1048576 : 0),
      modes: this.seg([['rule', '规则'], ['global', '全局'], ['direct', '直连']], s.mode, (mode) => this.setState({ mode })),
      routes: this.seg([['tun', '虚拟网卡'], ['proxy', '系统代理']], s.route, (route) => this.setState({ route })),
      goProxies: () => { go('proxies')(); this.setState({ group: '节点选择', proxOpen: true }); }, goWhitelist: go('whitelist'), goProfiles: go('profiles'), goActivity: go('activity'),
      wlSummary: s.wl ? applied + ' / ' + s.entries.length + ' 已加白' : '已关闭',
      wlChecked: s.wl ? 'true' : 'false',
      wlToggle: () => this.setState({ wl: !s.wl }),
      check: () => { if (!s.checking && s.wl) this.checkEntries(s.entries.map((e) => e.id)); },
      checkDisabled: s.checking || !s.wl,
      checkSpin: s.checking ? 'spin' : '',
      profileName: selected.name,
      profileUsed: selected.used,
      conns: s.on ? s.conns : 0,
      query: s.query,
      onQuery: (event) => this.setState({ query: event.target.value }),
      searching: s.searching,
      notSearching: !s.searching,
      openSearch: () => this.setState({ searching: true }),
      closeSearch: () => this.setState({ searching: false, query: '' }),
      focusRef: this.focusIn,
      groups: shownGroups.map((g) => {
        const d = delayOf(g.name);
        return {
          name: g.name,
          now: s.now[g.name],
          delay: delayText(d),
          tone: d === 0 ? 'dead' : d >= 600 ? 'slow' : '',
          cls: g.name === group.name ? 'sel act' : '',
          go: () => this.setState({ group: g.name, proxOpen: true, proxReturn: false }),
          pick: () => { this.setState({ group: g.name }); this.closeGroupMenu(); },
        };
      }),
      noGroups: shownGroups.length === 0,
      hasGroups: shownGroups.length > 0,
      groupName: group.name,
      groupNow: s.now[group.name],
      proxCls: (s.proxOpen ? 'open' : '') + (s.proxReturn ? ' back' : ''),
      isProxOpen: s.page === 'proxies' && s.proxOpen,
      proxBack: () => this.setState({ proxOpen: false, proxReturn: true }),
      groupMenuOpen: !!s.groupMenu,
      groupMenuRef: this.setGroupMenu,
      gmTop: s.groupMenu ? s.groupMenu.top : 0,
      gmLeft: s.groupMenu ? s.groupMenu.left : 0,
      gmWidth: s.groupMenu ? s.groupMenu.width : 0,
      openGroupMenu: (event) => {
        const button = event.currentTarget.getBoundingClientRect();
        const root = this.root.getBoundingClientRect();
        this.setState({ groupMenu: { top: button.bottom - root.top + 4, left: button.left - root.left, width: button.width }, menuClosing: false });
      },
      closeGroupMenu: () => this.closeGroupMenu(),
      locate,
      sortLabel: SORTS.find(([id]) => id === s.sort)[1],
      openSort: (event) => this.openMenu(event, { kind: 'sort' }),
      openProxMenu: (event) => this.openMenu(event, { kind: 'prox' }),
      testDisabled: s.testing,
      notTesting: !s.testing,
      testLabel: s.testing ? '正在测试' : '测试延迟',
      test: () => {
        if (s.testing) return;
        const names = (PLATFORM === 'and' && !s.proxOpen ? ALL : group.nodes).filter((name) => name in DELAYS);
        const waiting = {};
        names.forEach((name) => { waiting[name] = true; });
        this.setState({ testing: true, waiting });
        names.forEach((name, n) => this.later(250 + n * 70, () => {
          const left = { ...this.state.waiting };
          delete left[name];
          const delay = DELAYS[name] === 0 ? 0 : Math.round(DELAYS[name] * (0.85 + Math.random() * 0.3));
          this.setState({ waiting: left, delays: { ...this.state.delays, [name]: delay }, testing: Object.keys(left).length > 0 });
        }));
      },
      nodes: (!q || hit(group.name) ? group.nodes : group.nodes.filter(hit)).slice()
        .sort(s.sort === 'delay' ? (a, b) => rank(delayOf(a)) - rank(delayOf(b)) : s.sort === 'name' ? (a, b) => a.localeCompare(b) : () => 0)
        .map((name) => {
          const d = delayOf(name);
          const member = GROUPS.find((g) => g.name === name);
          return {
            name,
            kind: member ? member.kind : name === 'DIRECT' ? 'Direct' : name === 'REJECT' ? 'Reject' : KINDS[ALL.indexOf(name) % KINDS.length],
            delay: delayText(d),
            tone: (d === 0 ? 'dead' : d >= 600 ? 'slow' : '') + (s.waiting[name] ? ' wait' : ''),
            cls: (s.now[group.name] === name ? 'sel' : '') + (group.auto ? ' ro' : ''),
            ro: group.auto,
            go: group.auto ? undefined : () => this.setState({ now: { ...s.now, [group.name]: name } }),
          };
        }),
      profiles: s.profiles.map((p) => ({
        ...p,
        metered: !!p.pct,
        cls: (p.id === s.profile ? 'sel' : '') + (s.leaving[p.id] ? ' leaving' : '') + (s.entering[p.id] ? ' entering' : ''),
        spin: s.updating[p.id] ? 'spin' : '',
        moreIcon: s.updating[p.id] ? ICONS.refresh : ICONS.more,
        go: () => this.setState({ profile: p.id }),
        update: () => this.updateProfile(p.id),
        more: (event) => this.openMenu(event, { profile: p }),
      })),
      updateAll: () => s.profiles.forEach((p, n) => this.later(n * 150, () => this.updateProfile(p.id))),
      updatingAny: Object.keys(s.updating).length > 0,
      updateAllSpin: Object.keys(s.updating).length > 0 ? 'spin' : '',
      addProfile: () => this.setState({ dialog: { type: 'add-profile' }, dialogClosing: false }),
      addEntry: () => this.setState({ dialog: { type: 'add-wl' }, dialogClosing: false }),
      menuOpen: !!s.menu,
      menuCls: s.menuClosing ? 'closing' : '',
      menuTop: s.menu ? s.menu.top : 0,
      menuRight: s.menu ? s.menu.right : 0,
      closeMenu: () => this.closeMenu(),
      menuItems: !s.menu ? [] : s.menu.kind ? [
        ...(s.menu.kind === 'prox' ? [{ label: '定位当前节点', cls: '', go: () => { locate(); this.closeMenu(); } }] : []),
        ...SORTS.map(([id, label]) => ({ label, cls: id === s.sort ? 'picked' : '', go: () => { this.setState({ sort: id }); this.closeMenu(); } })),
      ] : [
        { label: '更新', cls: '', go: () => { this.updateProfile(s.menu.profile.id); this.closeMenu(); } },
        { label: '编辑', cls: '', go: () => this.closeMenu() },
        { label: '覆写', cls: '', go: () => this.closeMenu() },
        { label: '移除', cls: 'danger', go: () => { this.closeMenu(); this.setState({ dialog: { type: 'remove-profile', id: s.menu.profile.id, name: s.menu.profile.name }, dialogClosing: false }); } },
      ],
      entries: s.entries.map((e) => ({
        ...e,
        cls: (s.leaving[e.id] ? 'leaving' : '') + (s.entering[e.id] ? ' entering' : ''),
        outcome: !s.wl ? '已停用' : e.state === 'checking' ? '检查中' : '已加白',
        dot: !s.wl ? '' : e.state === 'checking' ? 'wait' : 'on',
        ip: s.wl && e.state === 'applied' ? '203.0.113.17' : '',
        remove: () => this.setState({ dialog: { type: 'remove-wl', id: e.id, name: e.name }, dialogClosing: false }),
      })),
      dialogOpen: !!dialog,
      dialogCls: s.dialogClosing ? 'closing' : '',
      dialogKind: dialog && dialog.type.startsWith('add') ? 'as-sheet' : '',
      dialogTitle,
      dialogWl: !!dialog && dialog.type === 'add-wl',
      dialogProfile: !!dialog && dialog.type === 'add-profile',
      dialogAdd: !!dialog && dialog.type.startsWith('add'),
      dialogConfirm: !dialog ? '' : dialog.type.startsWith('add') ? '添加' : '移除',
      confirmCls: dialog && !dialog.type.startsWith('add') ? 'danger' : '',
      confirmDisabled: !!dialog && dialog.type.startsWith('add') && !s.formText.trim(),
      formText: s.formText,
      formName: s.formName,
      onFormText: (event) => this.setState({ formText: event.target.value }),
      onFormName: (event) => this.setState({ formName: event.target.value }),
      closeDialog: () => this.closeDialog(),
      confirm: () => this.confirmDialog(),
      activityTabs: this.seg([['requests', '请求'], ['connections', '连接'], ['logs', '日志']], s.activity, (activity) => this.setState({ activity })),
      isLogs: s.activity === 'logs',
      notLogs: s.activity !== 'logs',
      conn: (s.activity === 'requests' ? [...CONN].reverse() : CONN).map(([host, rule, chain, size]) => ({ host, rule, chain, size })),
      logs: LOGS.map(([level, text]) => ({ level, text })),
      themes: this.seg([['light', '浅色'], ['dark', '深色']], theme, (next) => {
        this.setState({ theme: next, theming: true });
        this.later(240, () => this.setState({ theming: false }));
      }),
      toolsA: [['application', '应用'], ['hotkeys', '快捷键']].map(([id, label]) => ({ label, go: id === 'application' ? () => this.setState({ drill: 'application', drillDir: 'drill', scrolled: false }) : undefined })),
      toolsB: ['基础配置', '网络', 'DNS', '高级', '资源', '代理集与规则集', '规则', '回环'],
      toolsC: ['备份与恢复', '诊断日志', '关于'],
      optionGroups: APP_OPTIONS.map(([title, rows]) => ({
        title,
        rows: rows.map(([id, label]) => ({ label, checked: s.options[id] ? 'true' : 'false', toggle: () => this.setState({ options: { ...s.options, [id]: !s.options[id] } }) })),
      })),
    };
  }
}
