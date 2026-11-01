const PLATFORM = '__PLATFORM__';
const ICONS = {
  refresh: 'M20 11a8 8 0 1 0-2.3 6M20 5v6h-6',
  moreH: 'M5 12h.01M12 12h.01M19 12h.01',
  search: 'M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14ZM20 20l-4-4',
  trash: 'M4 7h16M9 7V4h6v3M6.5 7l1 13h9l1-13',
  chevron: 'M9 5l7 7-7 7',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  plus: 'M12 5v14M5 12h14',
};
const NAV = [
  ['home', '仪表盘', 'M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z'],
  ['proxies', '代理', 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18ZM3 12h18M12 3c3 3 3.5 6 3.5 9s-.5 6-3.5 9c-3-3-3.5-6-3.5-9s.5-6 3.5-9Z'],
  ['profiles', '配置', 'M12 3 3 8l9 5 9-5-9-5ZM3 13l9 5 9-5M3 18l9 5 9-5'],
  ['whitelist', '加白', 'M12 3l8 3v6c0 4.5-3.2 7.6-8 9-4.8-1.4-8-4.5-8-9V6l8-3ZM8.5 12l2.5 2.5 4.5-5'],
  ['tools', '工具', 'M4 7h9M17 7h3M4 17h3M11 17h9M13 5h4v4h-4zM7 15h4v4H7z'],
];
const CLOSE_MS = PLATFORM === 'win' ? 90 : 210;
const NAMES = ['东京 03', '东京 07', '香港 01', '新加坡 02', '台北 01', '首尔 01', '大阪 02'];

class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.timers = [];
    this.next = 3;
    this.state = {
      mode: 'rule', route: 'tun', tab: 'connections', chip: '节点选择', on: true, off: false, radio: 'a', list: '东京 03', nav: 'home', pct: 37,
      rows: [{ id: 'r0', name: '东京 03' }, { id: 'r1', name: '东京 07' }, { id: 'r2', name: '香港 01' }], leaving: {}, entering: {},
      conn: 'on', menu: null, menuClosing: false, dialog: null, dialogClosing: false, formText: '', formName: '',
    };
    this.setRoot = (el) => { this.root = el; };
    this.focusIn = (el) => { if (el) el.focus(); };
    this.ripple = (event) => {
      if (PLATFORM !== 'and' || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
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

  componentWillUnmount() {
    this.timers.forEach(clearTimeout);
  }

  later(ms, fn) {
    this.timers.push(setTimeout(fn, ms));
  }

  seg(list, key) {
    const value = this.state[key];
    return {
      n: list.length,
      i: Math.max(0, list.findIndex(([id]) => id === value)),
      items: list.map(([id, label]) => ({ label, cls: id === value ? 'act' : '', go: () => this.setState({ [key]: id }) })),
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

  renderVals() {
    const s = this.state;
    const theme = this.props.theme ?? 'light';
    const dialog = s.dialog;
    return {
      i: ICONS,
      rootRef: this.setRoot,
      onPointerDown: this.ripple,
      rootCls: theme + ' pal-' + (this.props.palette ?? 'b'),
      modes: this.seg([['rule', '规则'], ['global', '全局'], ['direct', '直连']], 'mode'),
      routes: this.seg([['tun', '虚拟网卡'], ['proxy', '系统代理']], 'route'),
      tabs: this.seg([['requests', '请求'], ['connections', '连接'], ['logs', '日志']], 'tab'),
      chips: ['节点选择', '自动选择', 'AI'].map((name) => ({ name, cls: name === s.chip ? 'act' : '', go: () => this.setState({ chip: name }) })),
      swOn: s.on ? 'true' : 'false',
      swOff: s.off ? 'true' : 'false',
      toggleOn: () => this.setState({ on: !s.on }),
      toggleOff: () => this.setState({ off: !s.off }),
      radioA: s.radio === 'a' ? 'on' : '',
      radioB: s.radio === 'b' ? 'on' : '',
      pickA: () => this.setState({ radio: 'a' }),
      pickB: () => this.setState({ radio: 'b' }),
      list: NAMES.slice(0, 3).map((name) => ({ name, cls: name === s.list ? 'sel' : '', go: () => this.setState({ list: name }) })),
      navI: NAV.findIndex(([id]) => id === s.nav),
      navItems: NAV.map(([id, label, icon]) => ({ label, icon, cls: id === s.nav ? 'act' : '', go: () => this.setState({ nav: id }) })),
      pct: s.pct + '%',
      bump: () => this.setState({ pct: 10 + Math.floor(Math.random() * 85) }),
      rows: s.rows.map((row) => ({
        ...row,
        cls: (s.leaving[row.id] ? 'leaving' : '') + (s.entering[row.id] ? ' entering' : ''),
        remove: () => {
          this.setState({ leaving: { ...this.state.leaving, [row.id]: true } });
          this.later(210, () => this.setState({ rows: this.state.rows.filter((item) => item.id !== row.id) }));
        },
      })),
      addRow: () => {
        const id = 'r' + this.next++;
        this.setState({ rows: [...s.rows, { id, name: NAMES[this.next % NAMES.length] }], entering: { ...s.entering, [id]: true } });
      },
      connDot: s.conn === 'on' ? 'on' : s.conn === 'wait' ? 'wait' : '',
      connText: s.conn === 'on' ? '已连接' : s.conn === 'wait' ? '正在连接…' : '未连接',
      connBtn: s.conn === 'on' ? '断开连接' : s.conn === 'wait' ? '正在连接' : '连接',
      connWait: s.conn === 'wait',
      connCls: s.conn === 'on' ? '' : 'primary',
      connToggle: () => {
        if (s.conn === 'wait') return;
        if (s.conn === 'on') return this.setState({ conn: 'off' });
        this.setState({ conn: 'wait' });
        this.later(1100, () => this.setState({ conn: 'on' }));
      },
      openMenu: (event) => {
        const button = event.currentTarget.getBoundingClientRect();
        const root = this.root.getBoundingClientRect();
        this.setState({ menu: { top: button.bottom - root.top + 4, right: root.right - button.right }, menuClosing: false });
      },
      menuOpen: !!s.menu,
      menuCls: s.menuClosing ? 'closing' : '',
      menuTop: s.menu ? s.menu.top : 0,
      menuRight: s.menu ? s.menu.right : 0,
      closeMenu: () => this.closeMenu(),
      menuItems: [
        { label: '更新', cls: '', go: () => this.closeMenu() },
        { label: '编辑', cls: '', go: () => this.closeMenu() },
        { label: '覆写', cls: '', go: () => this.closeMenu() },
        { label: '移除', cls: 'danger', go: () => this.closeMenu() },
      ],
      openAdd: () => this.setState({ dialog: 'add', dialogClosing: false }),
      openConfirm: () => this.setState({ dialog: 'confirm', dialogClosing: false }),
      dialogOpen: !!dialog,
      dialogCls: s.dialogClosing ? 'closing' : '',
      dialogKind: dialog === 'add' ? 'as-sheet' : '',
      dialogTitle: dialog === 'add' ? '添加加白项' : '移除「家里宽带」？',
      dialogAdd: dialog === 'add',
      dialogWl: dialog === 'add',
      dialogProfile: false,
      dialogConfirm: dialog === 'add' ? '添加' : '移除',
      confirmDisabled: dialog === 'add' && !s.formText.trim(),
      formText: s.formText,
      formName: s.formName,
      onFormText: (event) => this.setState({ formText: event.target.value }),
      onFormName: (event) => this.setState({ formName: event.target.value }),
      focusRef: this.focusIn,
      closeDialog: () => this.closeDialog(),
      confirm: () => this.closeDialog(),
    };
  }
}
