// Exercises GameHighlightsSearch end to end: structured inputs -> date-windowed YouTube search.
// The 2024-10-05 ALDS Game 1 is the regression case: before the window, the series' Games 3 and 4
// (10/9, 10/10) came back too.
GameHighlightsSearch.Request r = new GameHighlightsSearch.Request();
r.gameDate = '2024-10-05';
r.homeTeam = 'Yankees';
r.awayTeam = 'Royals';
List<GameHighlightsSearch.Result> out = GameHighlightsSearch.search(new List<GameHighlightsSearch.Request>{ r });
System.debug('STATUS=' + out[0].status + ' COUNT=' + out[0].videoCount);
for (GameHighlightsSearch.Video v : out[0].videos) {
    System.debug('VIDEO published=' + v.publishedAt + ' | ' + v.title);
}
System.debug('TEXT=' + out[0].videosText);

// Lenient parsing: every form an LLM is likely to emit must land on 2024-10-05; garbage must not.
for (String form : new List<String>{ '2024-10-05', '10/5/2024', '10-5-2024', 'October 5 2024', 'October 5, 2024', 'Oct 5 2024', '5 October 2024', 'Oct. 5, 2024', '2024-10-05T00:00:00Z' }) {
    System.debug('PARSE ' + form + ' -> ' + GameHighlightsSearch.parseDate(form));
}
System.debug('PARSE garbage -> ' + GameHighlightsSearch.parseDate('the fifth of never'));
GameHighlightsSearch.Request bad = new GameHighlightsSearch.Request();
bad.gameDate = 'the fifth of never';
bad.homeTeam = 'Yankees';
bad.awayTeam = 'Royals';
System.debug('BAD_DATE status=' + GameHighlightsSearch.search(new List<GameHighlightsSearch.Request>{ bad })[0].status);
