import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

/// Lightweight i18n. High-traffic strings are translated (en/id); anything not
/// in the map falls back to English / the key. Extend `_data` to localize more.
class AppStrings {
  const AppStrings(this.lang);
  final String lang;

  String t(String key) =>
      _data[key]?[lang] ?? _data[key]?['en'] ?? key;
}

final stringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(settingsStoreProvider).locale.languageCode;
  return AppStrings(lang);
});

const Map<String, Map<String, String>> _data = {
  'nav.compete': {'en': 'Compete', 'id': 'Bertanding'},
  'nav.schedule': {'en': 'Schedule', 'id': 'Jadwal'},
  'nav.organize': {'en': 'Organize', 'id': 'Kelola'},
  'nav.admin': {'en': 'Admin', 'id': 'Admin'},
  'nav.profile': {'en': 'Profile', 'id': 'Profil'},

  // ── Schedule tab ──
  'schedule.title': {'en': 'My schedule', 'id': 'Jadwal saya'},
  'schedule.playNow': {'en': 'Ready to play', 'id': 'Siap dimainkan'},
  'schedule.playNowSub': {
    'en': 'Your matches waiting for a result.',
    'id': 'Pertandingan Anda yang menunggu hasil.'
  },
  'schedule.upcoming': {'en': 'Upcoming', 'id': 'Akan datang'},
  'schedule.results': {'en': 'Recent results', 'id': 'Hasil terbaru'},
  'schedule.play': {'en': 'Play', 'id': 'Main'},
  'schedule.emptyTitle': {
    'en': 'Nothing scheduled yet',
    'id': 'Belum ada jadwal'
  },
  'schedule.emptySub': {
    'en': 'Join a competition from the Compete tab and it shows up here.',
    'id': 'Ikuti kompetisi dari tab Bertanding dan akan muncul di sini.'
  },
  'schedule.vs': {'en': 'vs', 'id': 'vs'},
  'schedule.wonBy': {'en': 'Won by {x}', 'id': 'Dimenangkan {x}'},
  'schedule.tbd': {'en': 'Waiting for opponent', 'id': 'Menunggu lawan'},
  'login.welcome': {'en': 'Welcome back', 'id': 'Selamat datang'},
  'login.subtitle': {
    'en': 'Sign in to join and run tournaments.',
    'id': 'Masuk untuk ikut dan mengelola turnamen.'
  },
  'login.email': {'en': 'Email', 'id': 'Email'},
  'login.password': {'en': 'Password', 'id': 'Kata sandi'},
  'login.signIn': {'en': 'Sign in', 'id': 'Masuk'},
  'login.create': {
    'en': 'New here? Create an account',
    'id': 'Baru di sini? Buat akun'
  },
  'login.adminDemo': {
    'en': 'Sign in as admin (demo)',
    'id': 'Masuk sebagai admin (demo)'
  },
  'browse.heroTitle': {
    'en': 'Compete. Organize. Win.',
    'id': 'Bertanding. Kelola. Menang.'
  },
  'browse.heroSub': {
    'en':
        'Join tournaments with secure QRIS entry, or run your own — we handle the bracket, you keep 90% of every entry.',
    'id':
        'Ikuti turnamen dengan pembayaran QRIS, atau buat sendiri — kami atur bagannya, Anda dapat 90% dari tiap pendaftaran.'
  },
  'browse.create': {'en': 'Create a competition', 'id': 'Buat kompetisi'},
  'browse.open': {'en': 'Open competitions', 'id': 'Kompetisi terbuka'},
  'onboarding.title': {
    'en': 'Choose your language & currency',
    'id': 'Pilih bahasa & mata uang'
  },
  'onboarding.subtitle': {
    'en': 'You can change this later in your profile.',
    'id': 'Anda bisa mengubahnya nanti di profil.'
  },
  'onboarding.language': {'en': 'Language', 'id': 'Bahasa'},
  'onboarding.currency': {'en': 'Currency', 'id': 'Mata uang'},
  'onboarding.welcomeTitle': {
    'en': 'Run real tournaments',
    'id': 'Gelar turnamen sungguhan'
  },
  'onboarding.welcomeSub': {
    'en': 'Brackets, live results and prizes — for your community, on any device.',
    'id': 'Bracket, hasil langsung, dan hadiah — untuk komunitasmu, di perangkat apa pun.'
  },
  'onboarding.languageTitle': {
    'en': 'Choose your language',
    'id': 'Pilih bahasamu'
  },
  'onboarding.currencyTitle': {
    'en': 'Choose your currency',
    'id': 'Pilih mata uangmu'
  },
  'onboarding.getStarted': {'en': 'Get started', 'id': 'Mulai'},
  'onboarding.skip': {'en': 'Skip', 'id': 'Lewati'},
  'common.continue': {'en': 'Continue', 'id': 'Lanjut'},
  'common.save': {'en': 'Save', 'id': 'Simpan'},
  'common.cancel': {'en': 'Cancel', 'id': 'Batal'},
  'common.back': {'en': 'Back', 'id': 'Kembali'},
  'common.retry': {'en': 'Retry', 'id': 'Coba lagi'},
  'common.tbd': {'en': 'TBD', 'id': 'TBA'},
  'common.notFound': {'en': 'Not found', 'id': 'Tidak ditemukan'},
  'common.copied': {'en': 'Copied', 'id': 'Disalin'},
  'profile.settings': {'en': 'Language & currency', 'id': 'Bahasa & mata uang'},

  // ── Bracket / rounds / standings ──
  'bracket.loadError': {
    'en': 'Could not load bracket',
    'id': 'Gagal memuat bagan'
  },
  'bracket.emptyTitle': {'en': 'No bracket yet', 'id': 'Belum ada bagan'},
  'bracket.emptySubtitle': {
    'en': 'The organizer generates it once registration closes.',
    'id': 'Penyelenggara membuatnya setelah pendaftaran ditutup.'
  },
  'bracket.group': {'en': 'Group', 'id': 'Grup'},
  'bracket.playoffs': {'en': 'Playoffs', 'id': 'Babak playoff'},
  'round.n': {'en': 'Round', 'id': 'Ronde'},
  'round.final': {'en': 'Final', 'id': 'Final'},
  'round.semifinals': {'en': 'Semifinals', 'id': 'Semifinal'},
  'round.quarterfinals': {'en': 'Quarterfinals', 'id': 'Perempat final'},
  'standings.title': {'en': 'Standings', 'id': 'Klasemen'},
  'standings.player': {'en': 'Player', 'id': 'Pemain'},
  'standings.w': {'en': 'W', 'id': 'M'},
  'standings.l': {'en': 'L', 'id': 'K'},
  'standings.pts': {'en': 'Pts', 'id': 'Poin'},
  'ffa.lobbies': {'en': 'Lobbies', 'id': 'Lobi'},
  'ffa.lobby': {'en': 'Lobby {n}', 'id': 'Lobi {n}'},
  'ffa.players': {'en': '{n} players', 'id': '{n} pemain'},
  'ffa.setWinner': {'en': 'Lobby result', 'id': 'Hasil lobi'},
  'ffa.pickWinner': {
    'en': 'Who won this lobby?',
    'id': 'Siapa pemenang lobi ini?'
  },
  'ffa.rankAdvance': {
    'en': 'Tap players in finishing order — the top {n} advance.',
    'id': 'Ketuk pemain sesuai urutan finis — {n} teratas lolos.'
  },
  'ffa.rankFinal': {
    'en': 'Tap players in finishing order — the top {n} are the winners.',
    'id': 'Ketuk pemain sesuai urutan finis — {n} teratas jadi pemenang.'
  },
  'ffa.confirmResult': {'en': 'Confirm results', 'id': 'Konfirmasi hasil'},
  'ffa.place': {'en': 'Place {n}', 'id': 'Peringkat {n}'},
  'board.list': {'en': 'List', 'id': 'Daftar'},
  'board.bracket': {'en': 'Bracket', 'id': 'Bagan'},
  'board.headToHead': {'en': 'Head-to-head', 'id': 'Antar pemain'},

  // ── Create competition ──
  'create.title': {'en': 'New competition', 'id': 'Kompetisi baru'},
  'create.basics': {'en': 'Basics', 'id': 'Dasar'},
  'create.fieldTitle': {'en': 'Title', 'id': 'Judul'},
  'create.titleHint': {
    'en': 'e.g. Mobile Legends Weekend Cup',
    'id': 'mis. Piala Akhir Pekan Mobile Legends'
  },
  'create.addTitle': {'en': 'Add a title', 'id': 'Tambahkan judul'},
  'create.description': {
    'en': 'Description / rules',
    'id': 'Deskripsi / aturan'
  },
  'create.bannerUrl': {
    'en': 'Banner image URL (optional)',
    'id': 'URL gambar banner (opsional)'
  },
  'create.uploadBanner': {
    'en': 'Or upload a banner image',
    'id': 'Atau unggah gambar banner'
  },
  'create.bannerSelected': {
    'en': 'Banner image selected',
    'id': 'Gambar banner dipilih'
  },
  'create.format': {'en': 'Format', 'id': 'Format'},
  'create.elimination': {'en': 'Elimination', 'id': 'Eliminasi'},
  'create.roundRobin': {'en': 'Round robin', 'id': 'Round robin'},
  'create.freeForAll': {'en': 'Free-for-all', 'id': 'Bebas (FFA)'},
  'create.lobbySize': {
    'en': 'Players per match (lobby)',
    'id': 'Pemain per pertandingan (lobi)'
  },
  'create.lobbySizeHelp': {
    'en': 'Everyone in a lobby plays one match; top finishers advance.',
    'id': 'Semua pemain dalam satu lobi bermain satu pertandingan; peringkat teratas lolos.'
  },
  'create.ffaAdvance': {
    'en': 'Advance per lobby',
    'id': 'Lolos per lobi'
  },
  'create.finalWinners': {
    'en': 'Winners in the final',
    'id': 'Pemenang di final'
  },
  'create.ffaHelp': {
    'en': 'Top players from each lobby advance round by round; the final lobby '
        'crowns the winners.',
    'id': 'Pemain teratas tiap lobi lolos ronde demi ronde; lobi final '
        'menentukan pemenang.'
  },
  'create.groups': {'en': 'Groups', 'id': 'Grup'},
  'create.oneGroup': {'en': 'One group', 'id': 'Satu grup'},
  'create.perGroup': {'en': '{n} / group', 'id': '{n} / grup'},
  'create.advance': {
    'en': 'Top players per group that advance',
    'id': 'Pemain teratas per grup yang lolos'
  },
  'create.playoff': {
    'en': 'Final elimination playoff',
    'id': 'Playoff eliminasi akhir'
  },
  'create.playoffSub': {
    'en': 'Top finishers advance to a single-elimination bracket.',
    'id': 'Peringkat teratas lanjut ke bagan eliminasi tunggal.'
  },
  'create.validateAdvance': {
    'en': 'Players advancing must be fewer than the group size.',
    'id': 'Jumlah yang lolos harus lebih kecil dari ukuran grup.'
  },
  'create.validateDivide': {
    'en': "{n} players don't split evenly into groups of {g}; the last group "
        'will be smaller.',
    'id': '{n} pemain tidak terbagi rata ke grup berisi {g}; grup terakhir '
        'akan lebih kecil.'
  },
  'create.capacityMoney': {
    'en': 'Capacity & money',
    'id': 'Kapasitas & biaya'
  },
  'create.maxParticipants': {
    'en': 'Max participants',
    'id': 'Maks peserta'
  },
  'create.min2': {'en': 'Min 2', 'id': 'Min 2'},
  'create.entryFee': {'en': 'Entry fee', 'id': 'Biaya pendaftaran'},
  'create.prizePool': {
    'en': 'Prize pool (optional)',
    'id': 'Total hadiah (opsional)'
  },
  'create.feeFree': {
    'en': 'Free entry — no platform fee.',
    'id': 'Pendaftaran gratis — tanpa biaya platform.'
  },
  'create.feeNote': {
    'en': 'Platform fee is 10%. You receive {x} per paid registration.',
    'id': 'Biaya platform 10%. Anda menerima {x} per pendaftaran berbayar.'
  },
  'create.schedule': {
    'en': 'Schedule & technical meeting',
    'id': 'Jadwal & technical meeting'
  },
  'create.pickDate': {'en': 'Pick a start date', 'id': 'Pilih tanggal mulai'},
  'create.startsOn': {'en': 'Starts {x}', 'id': 'Mulai {x}'},
  'create.deadlineNone': {
    'en': 'Registration deadline (optional)',
    'id': 'Batas pendaftaran (opsional)'
  },
  'create.deadlineOn': {
    'en': 'Registration closes {x}',
    'id': 'Pendaftaran ditutup {x}'
  },
  'create.choose': {'en': 'Choose', 'id': 'Pilih'},
  'create.meetingLink': {'en': '{x} invite link', 'id': 'Tautan undangan {x}'},
  'create.publish': {
    'en': 'Publish competition',
    'id': 'Terbitkan kompetisi'
  },
  'create.shareNote': {
    'en': 'A public share link is generated automatically on publish.',
    'id': 'Tautan berbagi publik dibuat otomatis saat diterbitkan.'
  },
  'create.createdShare': {
    'en': 'Created · share link {x}',
    'id': 'Dibuat · tautan {x}'
  },
  'create.failed': {'en': 'Failed: {x}', 'id': 'Gagal: {x}'},

  // ── Manage competition ──
  'manage.title': {'en': 'Manage', 'id': 'Kelola'},
  'manage.registered': {'en': '{n} registered', 'id': '{n} terdaftar'},
  'manage.bracket': {'en': 'Bracket', 'id': 'Bagan'},
  'manage.bracketHint': {
    'en': 'Tap a match to view streams, reports, or resolve it. Results '
        'auto-confirm 5 minutes after a report (or use Resolve now).',
    'id': 'Ketuk pertandingan untuk lihat stream, laporan, atau selesaikan. '
        'Hasil terkonfirmasi otomatis 5 menit setelah laporan (atau Selesaikan sekarang).'
  },
  'manage.closeStart': {
    'en': 'Close registration & start',
    'id': 'Tutup pendaftaran & mulai'
  },
  'manage.generateInfo': {
    'en': 'Generates the {fmt} bracket from the paid participants. The '
        'auto-resolve window is {min} min.',
    'id': 'Membuat bagan {fmt} dari peserta yang sudah membayar. Jendela '
        'penyelesaian otomatis {min} menit.'
  },
  'manage.demoPad': {
    'en': 'Demo mode pads with practice opponents so you can play through a '
        'full bracket on your own.',
    'id': 'Mode demo menambah lawan latihan agar Anda bisa memainkan bagan '
        'penuh sendiri.'
  },
  'manage.generateBracket': {
    'en': 'Generate bracket',
    'id': 'Buat bagan'
  },
  'manage.playoffsTitle': {'en': 'Final playoffs', 'id': 'Playoff akhir'},
  'manage.playoffsLive': {
    'en': 'The elimination playoff is live — the top {n} of each group advanced.',
    'id': 'Playoff eliminasi berjalan — {n} teratas tiap grup telah lolos.'
  },
  'manage.playoffsReady': {
    'en': 'All group matches are done. Generate the single-elimination playoff '
        'from the group standings.',
    'id': 'Semua pertandingan grup selesai. Buat playoff eliminasi tunggal '
        'dari klasemen grup.'
  },
  'manage.playoffsLocked': {
    'en': 'Finish every group match to unlock the playoff bracket.',
    'id': 'Selesaikan semua pertandingan grup untuk membuka bagan playoff.'
  },
  'manage.generatePlayoffs': {
    'en': 'Generate playoffs',
    'id': 'Buat playoff'
  },
  'manage.playoffsDone': {'en': 'Playoffs generated', 'id': 'Playoff dibuat'},
  'manage.participants': {'en': 'Participants', 'id': 'Peserta'},
  'manage.participantsHint': {
    'en': 'Tap WhatsApp to message a player and add them to your group, or copy '
        'their number for Telegram.',
    'id': 'Ketuk WhatsApp untuk menghubungi pemain dan menambahkannya ke grup, '
        'atau salin nomornya untuk Telegram.'
  },
  'manage.noParticipants': {'en': 'No participants yet.', 'id': 'Belum ada peserta.'},
  'manage.noPhone': {'en': 'No phone provided', 'id': 'Tidak ada nomor telepon'},
  'manage.waOpenError': {
    'en': 'Could not open WhatsApp',
    'id': 'Tidak dapat membuka WhatsApp'
  },
  'manage.numberCopied': {'en': 'Number copied', 'id': 'Nomor disalin'},
  'manage.cancelTitle': {
    'en': 'Cancel competition?',
    'id': 'Batalkan kompetisi?'
  },
  'manage.cancelBody': {
    'en': 'Registrations will be refunded and the bracket removed. This cannot '
        'be undone.',
    'id': 'Pendaftaran akan dikembalikan dan bagan dihapus. Tindakan ini tidak '
        'dapat dibatalkan.'
  },
  'manage.keep': {'en': 'Keep', 'id': 'Pertahankan'},
  'manage.cancelIt': {'en': 'Cancel it', 'id': 'Batalkan'},
  'manage.cancelButton': {
    'en': 'Cancel competition (refund all)',
    'id': 'Batalkan kompetisi (kembalikan semua)'
  },

  // ── Match detail ──
  'match.title': {'en': 'Match', 'id': 'Pertandingan'},
  'match.notFound': {'en': 'Match not found', 'id': 'Pertandingan tidak ditemukan'},
  'match.streams': {'en': 'Streams', 'id': 'Stream'},
  'match.addStream': {'en': 'Add stream link', 'id': 'Tambah tautan stream'},
  'match.noStreams': {
    'en': 'No streams linked yet.',
    'id': 'Belum ada stream tertaut.'
  },
  'match.reportResult': {'en': 'Report result', 'id': 'Laporkan hasil'},
  'match.pickWinner': {'en': 'Who won?', 'id': 'Siapa yang menang?'},
  'match.uploadScreenshot': {
    'en': 'Upload screenshot',
    'id': 'Unggah tangkapan layar'
  },
  'match.screenshotAdded': {
    'en': 'Screenshot selected',
    'id': 'Tangkapan layar dipilih'
  },
  'match.submitReport': {'en': 'Submit report', 'id': 'Kirim laporan'},
  'match.resolveNow': {'en': 'Resolve now', 'id': 'Selesaikan sekarang'},
  'match.reports': {'en': 'Reports', 'id': 'Laporan'},
  'match.winner': {'en': 'Winner', 'id': 'Pemenang'},
  'match.disputed': {
    'en': 'Players disagree — pick the winner to resolve.',
    'id': 'Pemain tidak sepakat — pilih pemenang untuk menyelesaikan.'
  },
  'match.url': {'en': 'Stream URL', 'id': 'URL stream'},
  'match.add': {'en': 'Add', 'id': 'Tambah'},
  'match.noReports': {'en': 'No reports yet.', 'id': 'Belum ada laporan.'},
  'match.reportedBy': {'en': '{x} reported', 'id': '{x} melaporkan'},
  'match.winnerLabel': {'en': 'Winner: {x}', 'id': 'Pemenang: {x}'},
  'match.reportButton': {
    'en': 'Report result + screenshot',
    'id': 'Laporkan hasil + tangkapan layar'
  },
  'match.resolveNowFull': {
    'en': 'Resolve now (skip 5-min wait)',
    'id': 'Selesaikan sekarang (lewati 5 menit)'
  },
  'match.resolveDispute': {'en': 'Resolve dispute', 'id': 'Selesaikan sengketa'},
  'match.attach': {'en': 'Attach screenshot', 'id': 'Lampirkan tangkapan layar'},
  'match.attached': {
    'en': 'Screenshot attached',
    'id': 'Tangkapan layar dilampirkan'
  },
  'match.simDispute': {
    'en': 'Simulate opponent disagreeing',
    'id': 'Simulasikan lawan tidak setuju'
  },
  'match.simDisputeSub': {
    'en': 'Triggers the dispute flow (demo).',
    'id': 'Memicu alur sengketa (demo).'
  },
  'match.liveStreams': {'en': 'Live streams', 'id': 'Stream langsung'},
  'match.resultReports': {'en': 'Result reports', 'id': 'Laporan hasil'},

  // ── Public tournament page ──
  'public.notFound': {
    'en': 'Tournament not found',
    'id': 'Turnamen tidak ditemukan'
  },
  'public.notFoundSub': {
    'en': 'This share link may be wrong or the tournament was removed.',
    'id': 'Tautan ini mungkin salah atau turnamen telah dihapus.'
  },
  'public.signInToRegister': {
    'en': 'Sign in to register',
    'id': 'Masuk untuk mendaftar'
  },
  'public.openInApp': {'en': 'Open in app', 'id': 'Buka di aplikasi'},
  'public.viewerNote': {
    'en': 'Public tournament page — anyone with the link can follow along.',
    'id': 'Halaman turnamen publik — siapa pun dengan tautan bisa mengikuti.'
  },
  'public.addToCalendar': {
    'en': 'Add to calendar',
    'id': 'Tambah ke kalender'
  },

  // ── Competition detail ──
  'detail.loadError': {'en': 'Could not load', 'id': 'Gagal memuat'},
  'detail.playersCount': {'en': '{a}/{b} players', 'id': '{a}/{b} pemain'},
  'detail.entry': {'en': 'Entry', 'id': 'Pendaftaran'},
  'detail.joinFree': {'en': 'Join free', 'id': 'Gabung gratis'},
  'detail.closed': {'en': 'Closed', 'id': 'Ditutup'},
  'detail.bracket': {'en': 'Bracket', 'id': 'Bagan'},
  'detail.about': {'en': 'About', 'id': 'Tentang'},
  'detail.noDescription': {
    'en': 'No description provided.',
    'id': 'Tidak ada deskripsi.'
  },
  'detail.starts': {'en': 'Starts', 'id': 'Mulai'},
  'detail.regCloses': {'en': 'Registration closes', 'id': 'Pendaftaran ditutup'},
  'detail.regClosed': {'en': 'Registration closed', 'id': 'Pendaftaran ditutup'},
  'detail.meeting': {'en': '{x} meeting', 'id': 'Pertemuan {x}'},
  'detail.share': {'en': 'Share', 'id': 'Bagikan'},
  'detail.linkCopied': {'en': 'Link copied', 'id': 'Tautan disalin'},
  'detail.register': {'en': 'Register & pay', 'id': 'Daftar & bayar'},
  'detail.registered': {'en': "You're in", 'id': 'Anda terdaftar'},
  'detail.withdraw': {'en': 'Withdraw', 'id': 'Batalkan'},
  'detail.withdrawTitle': {
    'en': 'Withdraw from this tournament?',
    'id': 'Batalkan pendaftaran turnamen ini?'
  },
  'detail.withdrawBody': {
    'en': 'Your spot is freed. Paid entry fees are refunded (processed '
        'manually for now).',
    'id': 'Tempat Anda dilepas. Biaya pendaftaran yang sudah dibayar '
        'dikembalikan (diproses manual untuk saat ini).'
  },
  'detail.withdrawn': {
    'en': 'You have withdrawn — your spot is freed.',
    'id': 'Pendaftaran dibatalkan — tempat Anda dilepas.'
  },
  'detail.full': {'en': 'Full', 'id': 'Penuh'},
  'detail.manage': {'en': 'Manage', 'id': 'Kelola'},
  'detail.paidUnavailable': {
    'en': 'Paid entry is not available in this app.',
    'id': 'Pendaftaran berbayar tidak tersedia di aplikasi ini.'
  },
  'detail.prizePool': {'en': 'Prize pool', 'id': 'Total hadiah'},
  'detail.entryFee': {'en': 'Entry fee', 'id': 'Biaya'},
  'detail.players': {'en': 'Players', 'id': 'Pemain'},

  // ── Checkout ──
  'checkout.title': {'en': 'Checkout', 'id': 'Pembayaran'},
  'checkout.yourDetails': {'en': 'Your details', 'id': 'Data Anda'},
  'checkout.phone': {'en': 'Phone number', 'id': 'Nomor telepon'},
  'checkout.phoneHelper': {
    'en': 'So the organizer can add you to the WhatsApp/Telegram group.',
    'id': 'Agar penyelenggara bisa menambahkan Anda ke grup WhatsApp/Telegram.'
  },
  'checkout.phoneInvalid': {
    'en': 'Enter a valid phone number',
    'id': 'Masukkan nomor telepon yang valid'
  },
  'checkout.payoutAccount': {
    'en': 'Reward payout account',
    'id': 'Akun penerima hadiah'
  },
  'checkout.payoutSub': {
    'en': 'Where winnings are sent (bank or e-wallet). Optional — you can add '
        'one later before claiming a reward.',
    'id': 'Tujuan pengiriman hadiah (bank atau e-wallet). Opsional — bisa '
        'ditambahkan nanti sebelum klaim hadiah.'
  },
  'checkout.addAccount': {
    'en': 'Add bank / e-wallet',
    'id': 'Tambah bank / e-wallet'
  },
  'checkout.manageAccounts': {
    'en': 'Manage payout accounts',
    'id': 'Kelola akun penerima'
  },
  'checkout.continueJoin': {'en': 'Continue to join', 'id': 'Lanjut bergabung'},
  'checkout.continuePay': {
    'en': 'Continue to payment',
    'id': 'Lanjut ke pembayaran'
  },
  'checkout.startError': {
    'en': 'Could not start payment',
    'id': 'Tidak dapat memulai pembayaran'
  },
  'checkout.scanHint': {
    'en': 'Scan with any QRIS app — GoPay, OVO, DANA, ShopeePay, m-banking',
    'id': 'Pindai dengan aplikasi QRIS apa pun — GoPay, OVO, DANA, ShopeePay, m-banking'
  },
  'checkout.mockNote': {
    'en': 'Mock mode — no real charge. Use the button below to simulate a '
        'successful QRIS payment.',
    'id': 'Mode simulasi — tanpa biaya nyata. Gunakan tombol di bawah untuk '
        'menyimulasikan pembayaran QRIS yang berhasil.'
  },
  'checkout.simulate': {
    'en': 'Simulate payment success',
    'id': 'Simulasikan pembayaran berhasil'
  },
  'checkout.waiting': {'en': 'Waiting for payment…', 'id': 'Menunggu pembayaran…'},
  'checkout.checkNow': {
    'en': "I've paid — check now",
    'id': 'Saya sudah bayar — periksa sekarang'
  },
  'checkout.notPaidYet': {
    'en': 'No payment detected yet — try again in a moment.',
    'id': 'Pembayaran belum terdeteksi — coba lagi sebentar.'
  },
  'checkout.entryFee': {'en': 'Entry fee', 'id': 'Biaya pendaftaran'},
  'checkout.platformFee': {'en': 'Platform fee (10%)', 'id': 'Biaya platform (10%)'},
  'checkout.organizerGets': {'en': 'Organizer receives', 'id': 'Penyelenggara menerima'},
  'checkout.youPay': {'en': 'You pay', 'id': 'Anda bayar'},
  'checkout.freeEntry': {
    'en': 'This competition is free to enter.',
    'id': 'Kompetisi ini gratis untuk diikuti.'
  },
  'checkout.confirmSpot': {'en': 'Confirm my spot', 'id': 'Konfirmasi tempat saya'},
  'checkout.joinError': {'en': 'Could not join: {x}', 'id': 'Gagal bergabung: {x}'},
  'checkout.successTitle': {'en': "You're in!", 'id': 'Anda terdaftar!'},
  'checkout.successBody': {
    'en': 'Registered for {x}. Check the competition page for the bracket and '
        'technical-meeting link.',
    'id': 'Terdaftar untuk {x}. Lihat halaman kompetisi untuk bagan dan tautan '
        'technical meeting.'
  },
  'checkout.backToComp': {'en': 'Back to competition', 'id': 'Kembali ke kompetisi'},

  // ── Profile ──
  'profile.title': {'en': 'Profile', 'id': 'Profil'},
  'profile.notSignedIn': {'en': 'Not signed in', 'id': 'Belum masuk'},
  'profile.payouts': {'en': 'Reward payouts', 'id': 'Pencairan hadiah'},
  'profile.payoutsSub': {
    'en': 'Bank / e-wallet accounts (DANA, OVO, …)',
    'id': 'Akun bank / e-wallet (DANA, OVO, …)'
  },
  'profile.myRegistrations': {'en': 'My registrations', 'id': 'Pendaftaran saya'},
  'profile.myRegistrationsSub': {
    'en': 'Competitions you joined',
    'id': 'Kompetisi yang Anda ikuti'
  },
  'profile.notifications': {'en': 'Notifications', 'id': 'Notifikasi'},
  'profile.notificationsSub': {
    'en': 'Match-ready, payments, payouts',
    'id': 'Pertandingan siap, pembayaran, pencairan'
  },
  'profile.settingsSub': {'en': 'English / Bahasa · \$ / Rp', 'id': 'English / Bahasa · \$ / Rp'},
  'profile.signOut': {'en': 'Sign out', 'id': 'Keluar'},
  'profile.role': {'en': 'Role', 'id': 'Peran'},

  // ── Admin ──
  'admin.title': {'en': 'Admin console', 'id': 'Konsol admin'},
  'admin.loadError': {'en': 'Could not load', 'id': 'Gagal memuat'},
  'admin.earnings': {'en': 'Platform earnings (10%)', 'id': 'Pendapatan platform (10%)'},
  'admin.competitions': {'en': 'Competitions', 'id': 'Kompetisi'},
  'admin.registrations': {'en': 'Registrations', 'id': 'Pendaftaran'},
  'admin.grossVolume': {'en': 'Gross volume', 'id': 'Volume kotor'},
  'admin.openDisputes': {'en': 'Open disputes', 'id': 'Sengketa terbuka'},
  'admin.appSettings': {'en': 'App settings', 'id': 'Pengaturan aplikasi'},
  'admin.config': {
    'en': 'Configuration (domain · QRIS · deploy)',
    'id': 'Konfigurasi (domain · QRIS · deploy)'
  },
  'admin.users': {'en': 'Users & roles', 'id': 'Pengguna & peran'},
  'admin.payouts': {'en': 'Payout requests', 'id': 'Permintaan pencairan'},
  'admin.payoutsEmpty': {'en': 'No payouts yet', 'id': 'Belum ada pencairan'},
  'admin.payoutsEmptySub': {
    'en': 'Rewards appear here when competitions finish.',
    'id': 'Hadiah muncul di sini saat kompetisi selesai.'
  },
  'admin.paid': {'en': 'Paid', 'id': 'Lunas'},
  'admin.markPaid': {'en': 'Mark paid', 'id': 'Tandai lunas'},
  'admin.disputes': {'en': 'Dispute resolution', 'id': 'Penyelesaian sengketa'},
  'admin.noDisputes': {'en': 'No open disputes', 'id': 'Tidak ada sengketa'},
  'admin.tapResolve': {
    'en': 'Players disagree — tap to resolve',
    'id': 'Pemain tidak sepakat — ketuk untuk menyelesaikan'
  },
  'admin.demoMode': {'en': 'Demo mode', 'id': 'Mode demo'},
  'admin.demoModeSub': {
    'en': 'Show sample competitions and fill brackets with practice bots.',
    'id': 'Tampilkan kompetisi contoh dan isi bagan dengan bot latihan.'
  },
  'admin.changeLogo': {'en': 'Change app logo', 'id': 'Ganti logo aplikasi'},
  'admin.logoSet': {'en': 'Custom logo set', 'id': 'Logo khusus diatur'},
  'admin.logoUpload': {
    'en': 'Upload an image to replace the default logo',
    'id': 'Unggah gambar untuk mengganti logo bawaan'
  },

  // ── Notifications ──
  'notif.title': {'en': 'Notifications', 'id': 'Notifikasi'},
  'notif.empty': {'en': 'No notifications yet', 'id': 'Belum ada notifikasi'},
  'notif.emptySub': {
    'en': 'Match results, payments and payouts will appear here.',
    'id': 'Hasil pertandingan, pembayaran, dan pencairan akan muncul di sini.'
  },
  'notif.markRead': {'en': 'Mark all read', 'id': 'Tandai semua dibaca'},

  // ── My registrations ──
  'myregs.title': {'en': 'My registrations', 'id': 'Pendaftaran saya'},
  'myregs.empty': {
    'en': 'No registrations yet',
    'id': 'Belum ada pendaftaran'
  },
  'myregs.emptySub': {
    'en': 'Join a competition from the Compete tab.',
    'id': 'Ikuti kompetisi dari tab Bertanding.'
  },

  // ── Signup ──
  'signup.title': {'en': 'Create your account', 'id': 'Buat akun Anda'},
  'signup.subtitle': {
    'en': 'Play in or organize tournaments.',
    'id': 'Ikut atau kelola turnamen.'
  },
  'signup.name': {'en': 'Display name', 'id': 'Nama tampilan'},
  'signup.nameError': {'en': 'Tell us your name', 'id': 'Masukkan nama Anda'},
  'signup.emailError': {'en': 'Enter your email', 'id': 'Masukkan email Anda'},
  'signup.passwordError': {
    'en': 'At least 6 characters',
    'id': 'Minimal 6 karakter'
  },
  'signup.create': {'en': 'Create account', 'id': 'Buat akun'},
  'signup.haveAccount': {
    'en': 'Already have an account? Sign in',
    'id': 'Sudah punya akun? Masuk'
  },

  // ── Payout accounts ──
  'payout.title': {'en': 'Reward payouts', 'id': 'Pencairan hadiah'},
  'payout.add': {'en': 'Add account', 'id': 'Tambah akun'},
  'payout.intro': {
    'en': 'Where should we send your winnings? Add a bank account or e-wallet '
        '(DANA, OVO, GoPay, ShopeePay). This is optional — you can skip it now '
        'and add one before your first payout.',
    'id': 'Ke mana kami kirim hadiah Anda? Tambahkan rekening bank atau '
        'e-wallet (DANA, OVO, GoPay, ShopeePay). Opsional — bisa dilewati dan '
        'ditambahkan sebelum pencairan pertama.'
  },
  'payout.noneTitle': {
    'en': 'No payout account yet',
    'id': 'Belum ada akun penerima'
  },
  'payout.noneSub': {
    'en': "That's fine — you don't have one on file. Add it any time before "
        'claiming a reward.',
    'id': 'Tidak masalah — belum ada yang tersimpan. Tambahkan kapan saja '
        'sebelum klaim hadiah.'
  },
  'payout.default': {'en': 'Default', 'id': 'Utama'},
  'payout.addTitle': {
    'en': 'Add payout account',
    'id': 'Tambah akun penerima'
  },
  'payout.holder': {'en': 'Account holder name', 'id': 'Nama pemilik akun'},
  'payout.required': {'en': 'Required', 'id': 'Wajib diisi'},
  'payout.accountNumber': {'en': 'Account number', 'id': 'Nomor rekening'},
  'payout.walletNumber': {
    'en': 'Phone / wallet number',
    'id': 'Nomor telepon / dompet'
  },
  'payout.save': {'en': 'Save', 'id': 'Simpan'},

  // ── Checkout: payment method + manual transfer ──
  'checkout.choosePayment': {
    'en': 'Choose a payment method',
    'id': 'Pilih metode pembayaran'
  },
  'checkout.payQris': {'en': 'QRIS', 'id': 'QRIS'},
  'checkout.payQrisSub': {
    'en': 'Scan with any e-wallet or m-banking',
    'id': 'Scan dengan e-wallet atau m-banking apa pun'
  },
  'checkout.transferTo': {
    'en': 'Transfer exactly {x} to',
    'id': 'Transfer tepat {x} ke'
  },
  'checkout.senderName': {
    'en': 'Sender name (optional)',
    'id': 'Nama pengirim (opsional)'
  },
  'checkout.senderHelp': {
    'en': 'Helps the admin match your transfer.',
    'id': 'Membantu admin mencocokkan transfer Anda.'
  },
  'checkout.iHaveTransferred': {
    'en': "I've transferred",
    'id': 'Saya sudah transfer'
  },
  'checkout.otherMethod': {
    'en': 'Choose another method',
    'id': 'Pilih metode lain'
  },
  'checkout.noManualAccounts': {
    'en': 'Manual transfer is not available right now.',
    'id': 'Transfer manual belum tersedia saat ini.'
  },
  'checkout.manualPending': {
    'en': 'Verifying your payment',
    'id': 'Memverifikasi pembayaran Anda'
  },
  'checkout.manualPendingBody': {
    'en': 'Your spot is held. An admin will confirm your {x} transfer shortly.',
    'id': 'Slot Anda ditahan. Admin akan mengonfirmasi transfer {x} Anda segera.'
  },

  // ── Admin: platform payment accounts ──
  'pay.accountsTitle': {
    'en': 'Payment accounts',
    'id': 'Rekening pembayaran'
  },
  'pay.accountsSub': {
    'en': 'Where players send manual transfers. Only filled-in, active accounts appear at checkout.',
    'id': 'Tujuan transfer manual pemain. Hanya rekening aktif yang terisi yang muncul saat checkout.'
  },
  'pay.notSet': {
    'en': 'Not set — tap to add',
    'id': 'Belum diatur — ketuk untuk isi'
  },
  'pay.inactive': {'en': 'Off', 'id': 'Nonaktif'},
  'pay.accountName': {
    'en': 'Account holder name',
    'id': 'Nama pemilik rekening'
  },
  'pay.accountNumber': {
    'en': 'Account / phone number',
    'id': 'Nomor rekening / HP'
  },
  'pay.bankName': {'en': 'Bank name', 'id': 'Nama bank'},
  'pay.instructions': {
    'en': 'Instructions (optional)',
    'id': 'Instruksi (opsional)'
  },
  'pay.active': {'en': 'Active', 'id': 'Aktif'},
  'pay.activeSub': {
    'en': 'Show this option to players at checkout.',
    'id': 'Tampilkan opsi ini ke pemain saat checkout.'
  },
  'pay.editAccount': {'en': 'Edit {x}', 'id': 'Ubah {x}'},
  'pay.saved': {'en': 'Account saved', 'id': 'Rekening disimpan'},

  // ── Admin: transactions ──
  'txn.title': {'en': 'Transactions', 'id': 'Transaksi'},
  'txn.empty': {'en': 'No transactions yet', 'id': 'Belum ada transaksi'},
  'txn.emptySub': {
    'en': 'Entry-fee payments show up here.',
    'id': 'Pembayaran biaya pendaftaran muncul di sini.'
  },
  'txn.needsReview': {'en': 'Needs review', 'id': 'Perlu ditinjau'},
  'txn.history': {'en': 'History', 'id': 'Riwayat'},
  'txn.confirm': {'en': 'Confirm', 'id': 'Konfirmasi'},
  'txn.reject': {'en': 'Reject', 'id': 'Tolak'},
  'txn.confirmed': {'en': 'Payment confirmed', 'id': 'Pembayaran dikonfirmasi'},
  'txn.rejected': {'en': 'Payment rejected', 'id': 'Pembayaran ditolak'},
  'txn.statusPaid': {'en': 'Paid', 'id': 'Lunas'},
  'txn.statusPending': {'en': 'Pending', 'id': 'Menunggu'},
  'txn.statusRejected': {'en': 'Rejected', 'id': 'Ditolak'},
  'txn.statusExpired': {'en': 'Expired', 'id': 'Kedaluwarsa'},

  // ── Admin: competition moderation ──
  'mod.title': {'en': 'Manage competitions', 'id': 'Kelola kompetisi'},
  'mod.empty': {'en': 'No competitions yet', 'id': 'Belum ada kompetisi'},
  'mod.manage': {'en': 'Open', 'id': 'Buka'},
  'mod.cancel': {'en': 'Cancel', 'id': 'Batalkan'},
  'mod.cancelTitle': {
    'en': 'Cancel competition?',
    'id': 'Batalkan kompetisi?'
  },
  'mod.cancelBody': {
    'en': 'The competition is marked cancelled and entry fees are refunded.',
    'id': 'Kompetisi ditandai dibatalkan dan biaya pendaftaran dikembalikan.'
  },
  'mod.delete': {'en': 'Delete', 'id': 'Hapus'},
  'mod.deleteTitle': {'en': 'Delete competition?', 'id': 'Hapus kompetisi?'},
  'mod.deleteBody': {
    'en': 'This permanently removes the competition and all its data. This cannot be undone.',
    'id': 'Ini menghapus kompetisi dan semua datanya secara permanen. Tidak dapat dibatalkan.'
  },
};
