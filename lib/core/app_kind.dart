/* (27-11-2026, his words: "ata lion madhe saglech kahi ahe mechanical hr store … ata he prtek app vegli karaychi aahe jas apan falcon
 * keli ani lion madhe connect keli … pratek app ata wegli asel bundel asel tr lion madhe connect asel"; his answers: each module its
 * own app like FALCON (its own Play Store page) and inside LION too; HR first; its name ELEPHANT) WHICH APP THIS BUILD IS.
 *
 *   lion     – the bundle: every module of the client (the app of today – si.sketchline.lion, and the app given by its file);
 *   elephant – HR alone: the attendance app's pages (Home, Attendance, Leave, papers, Me …) and nothing of Mechanical
 *              (si.sketchline.elephant, built with --dart-define=APP=elephant and RCL_STORE=elephant – .github/workflows/elephant.yml).
 *
 * The SAME code makes both: HR's pages are one, so a change of HR is in LION and in ELEPHANT together. */
library;

/// The app of this build ('lion' unless the build says otherwise).
const String kAppKind = String.fromEnvironment('APP', defaultValue: 'lion');

/// The same, as a function – a test puts its own here.
String Function() appKind = () => kAppKind;

/// ELEPHANT – HR's own app.
bool get isElephant => appKind() == 'elephant';
