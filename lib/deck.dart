import 'package:flutter/widgets.dart';

import 'layouts.dart';
import 'materialize.dart';
import 'whimsy_amazing.dart';
import 'whimsy_approaches.dart';
import 'whimsy_barriers.dart';
import 'whimsy_best.dart';
import 'whimsy_bird.dart';
import 'whimsy_builtown.dart';
import 'whimsy_callback.dart';
import 'whimsy_cambrian.dart';
import 'whimsy_compounds.dart';
import 'whimsy_dash.dart';
import 'whimsy_developers.dart';
import 'whimsy_drift.dart';
import 'whimsy_future.dart';
import 'whimsy_glitch.dart';
import 'whimsy_halfmillion.dart';
import 'whimsy_important.dart';
import 'whimsy_intent.dart';
import 'whimsy_jobtitle.dart';
import 'whimsy_learners.dart';
import 'whimsy_learning.dart';
import 'whimsy_nohands.dart';
import 'whimsy_notreplace.dart';
import 'whimsy_pixels.dart';
import 'whimsy_ribbon.dart';
import 'whimsy_prompt.dart';
import 'whimsy_scale.dart';
import 'whimsy_sixty.dart';
import 'whimsy_software.dart';
import 'whimsy_squishy.dart';
import 'whimsy_today.dart';
import 'whimsy_tokens.dart';
import 'whimsy_truth.dart';
import 'whimsy_verify.dart';
import 'whimsy_weird.dart';
import 'whimsy_whichstack.dart';
import 'whimsy_working.dart';

enum Section { ai, flutter, us }

class Slide {
  const Slide(
    this.body, {
    this.notes = '',
    this.section,
    this.cover = false,
    this.builds = 0,
    this.shatterOut = false,
  });
  final Widget body;
  final String notes;
  final Section? section;

  /// Uses the cover background and hides the section tracker.
  final bool cover;

  /// Extra clicks spent revealing parts of the slide before advancing.
  final int builds;

  /// Leave this slide by shattering it like glass (see shatter.dart).
  final bool shatterOut;
}

String img(String name) => 'assets/images/$name';

/// FlutterCon India 2026 keynote. Content mirrors the Google Slides deck
/// (1dFKQm6r3Q3RIv_ttB3FyphjqMJs38al4solWc9C4za8); layouts live in layouts.dart.
final List<Slide> deck = [
  // Opening
  Slide(
    const Cover(
      title: 'Why AI Makes Flutter\nMore Important, Not Less',
      byline: ['Eric Seidel', 'CEO of Shorebird', 'Co-founder of Flutter'],
    ),
    cover: true,
    notes: 'Thanks, Greg. Every tool is up in the air.',
  ),
  const Slide(
    PromptBox('“Why not prompt once and get two native apps?”'),
    notes: "The question going around online. It's wrong, and here's why.",
  ),
  Slide(
    TitleOver(
      title: 'But first …',
      size: 40,
      child: Picture(img('g3f3355e65d4_0_0.png')),
    ),
    notes: "Agents writing your code? Haven't typed code in a week? Compare to six months ago. Read the room; lean in or ease off.",
  ),
  Slide(
    Bio(
      name: 'Eric Seidel',
      lines: const [
        'Software Engineer, 20+ years',
        'Flutter co-founder',
        'Led Flutter & Dart at Google',
        'Previously WebKit, Safari, Chrome',
        'Founder & CEO, Shorebird',
      ],
      photo: img('g3f07557751c_0_164.jpg'),
    ),
    notes: 'Browsers, then started Flutter, then Shorebird. Decades on making portable the default. Shorebird: one line, booth later.',
  ),
  const Slide(
    TodayRoute(title: 'Today', items: ['AI', 'Flutter', 'Us'], size: 40),
    cover: true,
    notes: "Today you'll hear about building at scale and AI writing your code. This talk is why it all matters.",
  ),

  // AI
  const Slide(
    SectionDivider(eyebrow: 'AI', title: 'What changed'),
    section: Section.ai,
  ),
  const Slide(
    Statement(
      'Token prediction\nAt scale\nOn demand',
      reveal: true,
      below: {0: TokenPrediction()},
    ),
    section: Section.ai,
    builds: 2,
    notes: 'Not our first transition: PCs, the internet, mobile. "Mary had a little..." An expert at 3am, for pennies.',
  ),
  const Slide(
    GlitchStatement(
      'Expert one minute.\nWrong the next.\nEqually confident.',
      wrong: 1,
    ),
    section: Section.ai,
    notes: "What people call jagged intelligence. Amazing at some things, terrible at others, and it can't tell which is which.",
  ),
  const Slide(
    Verdicts(
      items: [(VerdictKind.good, 'Trivia'), (VerdictKind.bad, 'Learning')],
      words: {1: ForgetfulWord('Learning')},
    ),
    section: Section.ai,
    notes: "Trained on every open-source RecyclerView there is; knows Android's insides better than any of us. But they don't learn: training data plus the context we give them, and they wake up fresh every time.",
  ),
  const Slide(
    Verdicts(
      items: [
        (VerdictKind.good, 'Squishy inputs'),
        (VerdictKind.bad, 'Determinism'),
      ],
      words: {
        0: JellyWord('Squishy inputs'),
        1: SlotWord('Determinism', tries: ['Determinant', 'Detergent  ']),
      },
    ),
    section: Section.ai,
    notes: "For my whole career we packaged data as XML or JSON so software could read it. Now squishy input is fine. The flip side: ask three times, get three answers. Not a compiler, and another reason prompting once for two platforms is weak.",
  ),
  const Slide(
    Verdicts(items: [(VerdictKind.bad, 'Responsibility')]),
    section: Section.ai,
    notes: "Not taste: responsibility. They aren't human and don't exist in the real world. Someone has to own the result.",
  ),
  const Slide(
    RibbonStatement('It codes better than I do'),
    section: Section.ai,
    notes: '20+ years, and most of the time agents code better than I do. Not true six months ago.',
  ),
  const Slide(
    NoHandsStatement('Producing code is no longer a human job'),
    section: Section.ai,
    notes: '"Computer" used to be a job title. Those people became the first programmers.',
  ),
  const Slide(
    NotReplaceStatement(),
    section: Section.ai,
    notes: "Say it emphatically. I don't write code; I'm responsible for it. The need for engineers is growing.",
  ),

  // Flutter: does portable still matter?
  const Slide(
    SectionDivider(eyebrow: 'Flutter', title: 'Does portable still matter?'),
    section: Section.flutter,
  ),
  const Slide(
    Statement('“Just prompt native”'),
    section: Section.flutter,
    notes: 'Shopify went native. But most of these stories end up on portable anyway, often one portable stack to another (Discord). I think portable matters more now, for three reasons. Straight into the first.',
  ),

  // Reason 1
  const Slide(
    SectionDivider(
      eyebrow: 'Reason 1',
      title: 'Generation is cheap.\nOwnership isn’t.',
    ),
    section: Section.flutter,
    notes: "Generation is cheap; ownership isn't. Every line you wrote yesterday, you pay for today. Orders of magnitude more code per person per day makes that compounding cost the dominant one.",
  ),
  const Slide(
    CompoundsSlide(text: 'Code\ncompounds', size: 54),
    section: Section.flutter,
    notes: 'Every line you wrote yesterday, you pay for today: builds, tests, docs, tokens, context.',
  ),
  const Slide(
    SixtyStat(
      caption:
          'A unified codebase let SoFi cut roughly a million lines of code',
    ),
    section: Section.flutter,
    notes: "SoFi cut 60% of its code moving to Flutter. Who wouldn't take 60% off their token bill, their CI bill?",
  ),
  const Slide(
    HalfMillion('Half a million lines.\nOne person.\nOne month.'),
    section: Section.flutter,
    notes: "Six months ago a whole team at SoFi adding 500K lines a quarter was a lot. Now I do 500K a month, by myself. The point isn't me; it's the tools.",
  ),

  // Reason 2
  const Slide(
    SectionDivider(eyebrow: 'Reason 2', title: 'Every copy costs more'),
    section: Section.flutter,
    notes: "Two copies cost more than 2x: there's a third, coordination cost between them.",
  ),
  const Slide(
    DriftSlide('Two copies drift'),
    section: Section.flutter,
    notes: "If you found two ways to parse a string in your codebase, you'd delete one. Nobody argues for keeping both. Yet we entertain two completely separate ways to do everything in the app, just because of platforms. Bonkers. That subtle checkout code, copied from Swift to Kotlin: two copies drift. The only fix is to share.",
  ),
  const Slide(
    SyncGraph(text: 'Two codebases:\n3x the bill'),
    section: Section.flutter,
    notes: "Google teams moving to Flutter reported moving about 3x faster. The third x was the organization: two copies plus the link between them. Every copy you add has to stay in sync with every other one: three things is a triangle, five is a pentagram. You can build abstractions over them, but that's just sharing code.",
  ),
  const Slide(
    VerifySlide('Verify one thing, not two'),
    section: Section.flutter,
    notes: 'Nobody reads the code anymore. Verification is the job, so verify one thing.',
  ),

  // Reason 3
  const Slide(
    SectionDivider(eyebrow: 'Reason 3', title: 'One answer beats two'),
    section: Section.flutter,
    notes: "Code isn't for the machines. It's us writing down our intent.",
  ),
  const Slide(
    IntentStatement('Code captures intent'),
    section: Section.flutter,
    notes: 'Every piece of intent is the end of an argument. Argue once, build once, maintain once.',
  ),
  Slide(
    TitleOver(
      title: 'Single source of truth',
      size: 40,
      child: const SingleSource(),
    ),
    section: Section.flutter,
    notes: 'Without one, every change is coordination: two agents to do the work, a third to keep them in sync.',
  ),
  const Slide(
    Statement('Anyone can read it'),
    section: Section.flutter,
    notes: 'Our sales team follows our codebase through agents. Code is how the company coordinates now.',
  ),
  const Slide(
    ListSlide(
      title: 'Why portable matters more',
      items: [
        '1. Ownership is the cost.',
        '2. Every copy costs more.',
        '3. One answer beats two.',
      ],
      size: 36,
    ),
    section: Section.flutter,
    notes: 'The three reasons, summed up. Number them out loud.',
  ),

  // Which portable?
  const Slide(
    SectionDivider(eyebrow: 'Flutter', title: 'Which portable?'),
    section: Section.flutter,
    notes: "Bought into portable? Then which approach. We built Flutter because we'd tried the rest.",
  ),
  const Slide(
    BarriersSlide(text: 'The barriers\nbetween stacks\nare gone', size: 60),
    section: Section.flutter,
    notes: "Easy to get into any stack now, so stacks are judged on end quality, agent fit and maintenance. The iOS lead who wouldn't leave Swift isn't the blocker anymore.",
  ),
  const Slide(
    SectionDivider(
      eyebrow: 'Flutter',
      title: 'Three approaches\nto cross-platform',
    ),
    section: Section.flutter,
    notes: 'Three common approaches. One at a time.',
  ),
  const Slide(
    Approach(
      ProsCons(
        title: 'Share some logic',
        examples: 'Kotlin Multiplatform, C++',
        upside: 'Simple: stop copying that part',
        downside: 'Two UIs, plus the API and coordination between them',
      ),
      diagram: ShareLogicDiagram(),
    ),
    section: Section.flutter,
    notes: 'Share business logic, keep native UIs. You stop copying that part, but you still own two apps and the seam between them.',
  ),
  const Slide(
    Approach(
      ProsCons(
        title: 'Orchestrate native widgets',
        examples: 'React Native',
        upside: 'Easy to adopt; great for brownfield',
        downside:
            'Complexity: behavior lives in systems you can’t test everywhere',
      ),
      diagram: PuppetDiagram(),
    ),
    section: Section.flutter,
    notes: "How does this button behave? It lives in a system you can't test from your Windows machine.",
  ),
  const Slide(
    Approach(
      ProsCons(
        title: 'Bring your whole stack',
        examples: 'The web, Flutter, game engines',
        upside: 'Most portability and control; test anywhere',
        downside:
            'You carry the stack, and mimic each platform’s look and feel',
      ),
      diagram: CarryStackDiagram(),
    ),
    section: Section.flutter,
    notes: 'Test and verify everything anywhere, even iOS from Linux. The cost: you carry the whole stack, so the stack had better be good, and you mimic each platform’s widgets yourself.',
  ),
  const Slide(
    WhichStack('So which stack?'),
    section: Section.flutter,
    notes: 'Transition into Flutter. If you carry a stack, carry the best one.',
  ),
  const Slide(
    BestStatement('Flutter is the best we have.', emphasis: 'best'),
    section: Section.flutter,
    notes: "Flutter has been and remains the best portable software we have. Here's why, structurally.",
  ),
  const Slide(
    PixelStatement('You own every pixel'),
    section: Section.flutter,
    notes: 'One renderer, your code, top to bottom. The app looks and behaves the same everywhere, and you can test and verify all of it from one machine. No behavior hides in a system you can\'t see or test. Everything that follows comes from this.',
  ),
  Slide(
    TitleOver(
      title: 'It goes everywhere',
      child: HopGallery(
        items: [
          (img('ev_desk.png'), 'Desktop', const Offset(0.5, 0.166)),
          (img('ev_mob.png'), 'iOS and Android', const Offset(0.716, 0.024)),
          (img('ev_car.jpg'), 'Embedded', const Offset(0.3, 0)),
        ],
      ),
    ),
    section: Section.flutter,
    notes: "Because you own the pixels, Flutter goes wherever there's a screen: phones, web, desktop, smart home, cars (that's the 2026 Toyota RAV4's infotainment, shipping now; Lexus ES too), TVs. The same app on screens nobody planned for.",
  ),
  const Slide(
    FullBleed3D(
      title: 'You can do more',
      link: 'fscene.dev',
      child: MaterializeHelmet(),
    ),
    section: Section.flutter,
    shatterOut: true, // the click away breaks the slide like glass
    notes: "This slide is Flutter: Flutter Scene's Materialize demo (fscene.dev), running live inside the deck on Flutter GPU and Impeller. Wireframe, then glass shards, then the full PBR surface. Gorgeous 3D, made easy. Plus serious Windows desktop apps. You can do so much with Flutter that you can't with other systems.",
  ),
  const Slide(
    SplitVisual(text: 'Solid\nfoundations', visual: BrickFoundation()),
    section: Section.flutter,
    notes: 'Solid foundations are why it scales and why agents thrive on it. Scale: 1M+ apps on Play, nearly a third of new free iOS apps, millions of lines at Google, businesses in this city. Agents: one golden path; a fast loop (hot reload, hot restart, desktop with no emulator); they can see the app (widget, render and accessibility trees).',
  ),
  const Slide(
    ScaleList(
      title: 'Proven at scale',
      items: [
        '1M+ apps on Google Play',
        'Nearly a third of new free iOS apps',
        'Millions of lines of Dart at Google',
        'Google Ads, built in Dart',
      ],
      size: 32,
    ),
    section: Section.flutter,
    notes: 'Scale. Google has millions of lines of Dart; its ads product is built in Dart. And businesses in this city.',
  ),
  const Slide(
    Statement('Portable matters more.\nFlutter is how.'),
    section: Section.flutter,
    notes: 'Recap of the Flutter section.',
  ),

  // We're not done
  const Slide(
    SectionDivider(eyebrow: 'Flutter', title: 'We’re not done'),
    section: Section.flutter,
  ),
  const Slide(
    Statement('Flutter was built for humans'),
    section: Section.flutter,
    notes: 'Built for humans to drive. Now agents drive, and everyone is trying something.',
  ),
  Slide(
    CambrianWall(
      items: [
        (img('wall_im0.png'), 'Exact'),
        (img('wall_im1.png'), 'DartNative'),
        (img('wall_im2b.png'), 'Discord, rebuilt in Rust'),
        (img('wall_im3.png'), 'Skip'),
      ],
    ),
    section: Section.flutter,
    notes: '~10 new portable efforts last quarter. A Cambrian explosion. Few are serious; most are years from Flutter\'s quality.',
  ),
  const Slide(
    AmazingStatement(
      before: 'Flutter is good with agents.',
      lead: 'It could be ',
      word: 'amazing',
    ),
    section: Section.flutter,
    notes: 'Still designed around humans. It has to be designed soup to nuts around agents, or somebody else will. E.g. faster analyzer, system explained to agents, iOS from Linux productized.',
  ),
  const Slide(
    WorkingStatement('We’re working on it'),
    section: Section.flutter,
    notes: "That's why Shorebird exists.",
  ),

  // Us
  const Slide(
    SectionDivider(eyebrow: 'Us', title: 'What about the humans?'),
    section: Section.us,
    notes: "It's a wild time; we're living in the future. This is a human conference, not an agent conference. It's always about the humans: customers and developers.",
  ),
  const Slide(
    JobTitleStatement('The engineer’s job changed'),
    section: Section.us,
    notes: "First thing in this section. Not the same as three months ago, or a year ago. We don't even have the words yet.",
  ),
  const Slide(
    Statement('Our jobs changed.\nAnd stayed the same.'),
    section: Section.us,
    notes: 'Our job is still to deliver value to customers through technology. That core hasn\'t moved.',
  ),
  const Slide(
    SoftwareSlide('A lot more software'),
    section: Section.us,
    notes: '10x, 100x, 1000x more software. Software has been eating the world for 20-30 years and will keep on. An insatiable appetite for software, and for people who own it.',
  ),
  const Slide(
    DevelopersSlide('A lot more developers'),
    section: Section.us,
    notes: "Most won't call themselves Flutter developers.",
  ),
  const Slide(
    WeirdStatement('The new world is weird'),
    section: Section.us,
    notes: "We don't know yet. So many explorations, everyone experimenting. Here's mine.",
  ),
  Slide(
    TitleOver(
      title: 'This is how I work',
      size: 32,
      child: Picture(img('ceo_shot.png')),
    ),
    section: Section.us,
    notes: 'Screenshot. I live in it all day; I just talk to it. ~300K lines, never read the code. This is what makes half a million lines a month possible.',
  ),
  const Slide(
    BuiltOwnSlide('Everyone at Shorebird built their own'),
    section: Section.us,
    notes: 'Ops, PM, sales. Almost all Flutter and Dart, no mandate.',
  ),
  const Slide(
    LearnersQuote(
      text: 'In times of change, [learners inherit the earth], while {the learned} find themselves beautifully equipped to deal with <a world that no longer exists>.',
      by: 'Eric Hoffer',
    ),
    section: Section.us,
    notes: 'In times of change, it\'s about learning. Managers and business owners: give your people time and space to learn, to play and to fail. This conference\'s tagline is "Learning at scale."',
  ),
  const Slide(
    Statement('Your skills still matter'),
    section: Section.us,
    notes: 'Taste, scars, judgment: knowing when the agent is bluffing. I learned what a HyperLogLog was last week, from an agent.',
  ),
  const Slide(
    Statement('Our jobs changed.\nOwning what we build didn’t.'),
    section: Section.us,
    notes: 'Our jobs have changed, and then they haven\'t. We still own the outcome.',
  ),
  const Slide(
    Statement('This community can lead'),
    section: Section.us,
    notes: 'Good outcomes, good tools, kindness, going home to play with your kids instead of writing a second platform.',
  ),
  Slide(
    SplitImage(
      text: 'Build for people,\nnot platforms',
      image: img('g3f42c810597_1_12.png'),
      size: 56,
    ),
    section: Section.us,
    notes: 'People, not platforms.',
  ),
  const Slide(
    StampedCallback(
      question: 'Why not prompt once and get two apps?',
      answers: ['You’d own two.', 'You’d pay 3x.', 'You’d get two answers.'],
    ),
    section: Section.us,
    notes: 'Callback to the opening question. The three reasons, in a line you can take home: own two, pay 3x, two answers.',
  ),
  const Slide(
    ImportantStatement(
      lead: 'AI makes Flutter',
      more: 'more important',
      rest: 'not',
      less: 'less',
    ),
    section: Section.us,
    notes: 'Orders of magnitude more software is coming. Spend it on people, not on copies.',
  ),
  const Slide(
    FutureSkyline('Let’s go build the future'),
    section: Section.us,
    notes: "Enjoy this human conference. Learning is part of what you'll do today.",
  ),
  Slide(
    Cover(
      title: 'Thank you',
      logo: img('g3b572bde633_0_186.png'),
      logoOverlay: (perch, logo) => LandingBird(perch: perch, logo: logo),
      contact: 'eric@shorebird.dev',
    ),
    cover: true,
    notes: 'Find me after, or at the Shorebird booth. Shorebird OTA talk at 17:35.',
  ),
];
