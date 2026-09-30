/**
 * Invocable wrapper over the YouTube_Data_API named credential for the Highlight_Scout agent.
 *
 * Exists because Agent Script cannot bind an External Service action output named "200"
 * (status-code output names fail to compile as identifiers), so the ESR's operation is
 * re-exposed here with agent-friendly output names. The API key stays on the
 * YouTube_API external credential principal — never in this class.
 *
 * Inputs are structured (date + both teams) rather than a free-text query so the class,
 * not the LLM, builds the search and applies the date filter: YouTube's publishedAfter /
 * publishedBefore window brackets the game day, which keeps a playoff series' other games
 * out of the result (ruled 2026-09-09 after the ALDS G1/G3/G4 finding).
 *
 * videosText is the pre-rendered answer — the agent's reasoning block stores it in a
 * variable and presents it verbatim, so the response is grounded structurally.
 */
public with sharing class GameHighlightsSearch {
    public class Request {
        @InvocableVariable(
            label='Game date'
            description='The game date in ISO format, YYYY-MM-DD.'
            required=true
        )
        public String gameDate;
        @InvocableVariable(label='Home team' description='Home team name, e.g. Yankees.' required=true)
        public String homeTeam;
        @InvocableVariable(label='Away team' description='Away team name, e.g. Royals.' required=true)
        public String awayTeam;
    }

    public class Video {
        @InvocableVariable(label='Title')
        public String title;
        @InvocableVariable(label='Link')
        public String link;
        @InvocableVariable(label='Channel')
        public String channel;
        @InvocableVariable(label='Published')
        public String publishedAt;
    }

    public class Result {
        @InvocableVariable(label='Videos' description='Highlight videos published within two days of the game date, best match first.')
        public List<Video> videos;
        @InvocableVariable(label='Video count')
        public Integer videoCount;
        @InvocableVariable(label='Has data' description='Internal flag: whether any videos matched.')
        public Boolean hasData;
        @InvocableVariable(label='Videos as text' description='The videos pre-rendered as numbered lines: title, then link. Empty when nothing matched.')
        public String videosText;
        @InvocableVariable(label='Status' description='ok | no_results | bad_date | http_<code>')
        public String status;
    }

    private static final Integer WINDOW_DAYS = 2;

    @InvocableMethod(
        label='Search game highlights'
        description='Search YouTube for highlight videos of one baseball game, filtered to videos published within two days of the game date.'
        callout=true
    )
    public static List<Result> search(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            results.add(searchOne(r));
        }
        return results;
    }

    private static Result searchOne(Request r) {
        Result out = new Result();
        out.videos = new List<Video>();
        out.videosText = '';

        Date gameDay = parseDate(r.gameDate);
        if (gameDay == null) {
            out.status = 'bad_date:' + String.valueOf(r.gameDate);
            out.videoCount = 0;
            out.hasData = false;
            return out;
        }

        String query = r.awayTeam.trim() + ' vs ' + r.homeTeam.trim() + ' ' + longDate(gameDay) + ' highlights';
        String publishedAfter = String.valueOf(gameDay) + 'T00:00:00Z';
        String publishedBefore = String.valueOf(gameDay.addDays(WINDOW_DAYS)) + 'T00:00:00Z';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:YouTube_Data_API/youtube/v3/search' +
            '?part=snippet&type=video&maxResults=3' +
            '&publishedAfter=' + EncodingUtil.urlEncode(publishedAfter, 'UTF-8') +
            '&publishedBefore=' + EncodingUtil.urlEncode(publishedBefore, 'UTF-8') +
            '&q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );
        req.setMethod('GET');
        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> items = (List<Object>) body.get('items');
            if (items != null) {
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    Map<String, Object> id = (Map<String, Object>) item.get('id');
                    Map<String, Object> snippet = (Map<String, Object>) item.get('snippet');
                    if (id == null || snippet == null || id.get('videoId') == null) {
                        continue;
                    }
                    Video v = new Video();
                    v.title = (String) snippet.get('title');
                    v.channel = (String) snippet.get('channelTitle');
                    v.publishedAt = (String) snippet.get('publishedAt');
                    v.link = 'https://www.youtube.com/watch?v=' + (String) id.get('videoId');
                    out.videos.add(v);
                }
            }
            out.status = out.videos.isEmpty() ? 'no_results' : 'ok';
        } else {
            out.status = 'http_' + res.getStatusCode();
            System.debug(LoggingLevel.ERROR, 'YouTube search failed: HTTP ' + res.getStatusCode());
        }

        List<String> lines = new List<String>();
        for (Integer i = 0; i < out.videos.size(); i++) {
            lines.add((i + 1) + '. ' + out.videos[i].title + '\n   ' + out.videos[i].link);
        }
        out.videosText = String.join(lines, '\n');
        out.videoCount = out.videos.size();
        out.hasData = !out.videos.isEmpty();
        return out;
    }

    private static final List<String> MONTHS = new List<String>{
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
    };

    /** "October 5, 2024" — the form that matches how highlight titles and descriptions are written. */
    private static String longDate(Date d) {
        return MONTHS[d.month() - 1].capitalize() + ' ' + d.day() + ', ' + d.year();
    }

    /**
     * Lenient date parsing so the LLM's formatting choice can't sink the search:
     * 2024-10-05 · 10/5/2024 · 10-5-2024 · October 5 2024 · October 5, 2024 · Oct 5 2024 · 5 October 2024.
     * Returns null when nothing matches — the caller reports bad_date with the raw text.
     */
    public static Date parseDate(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String s = raw.trim().toLowerCase().replaceAll('[,.]', ' ').replaceAll('\\s+', ' ').trim();
        // ISO 2024-10-05 (also tolerates a trailing time)
        Matcher m = Pattern.compile('^(\\d{4})-(\\d{1,2})-(\\d{1,2})').matcher(s);
        if (m.find()) {
            return safeDate(Integer.valueOf(m.group(1)), Integer.valueOf(m.group(2)), Integer.valueOf(m.group(3)));
        }
        // US numeric 10/5/2024 or 10-5-2024
        m = Pattern.compile('^(\\d{1,2})[/-](\\d{1,2})[/-](\\d{4})$').matcher(s);
        if (m.find()) {
            return safeDate(Integer.valueOf(m.group(3)), Integer.valueOf(m.group(1)), Integer.valueOf(m.group(2)));
        }
        // Month-name forms: "october 5 2024" / "oct 5 2024" / "5 october 2024"
        m = Pattern.compile('^([a-z]+) (\\d{1,2}) (\\d{4})$').matcher(s);
        if (m.find()) {
            Integer mo = monthIndex(m.group(1));
            return mo == null ? null : safeDate(Integer.valueOf(m.group(3)), mo, Integer.valueOf(m.group(2)));
        }
        m = Pattern.compile('^(\\d{1,2}) ([a-z]+) (\\d{4})$').matcher(s);
        if (m.find()) {
            Integer mo = monthIndex(m.group(2));
            return mo == null ? null : safeDate(Integer.valueOf(m.group(3)), mo, Integer.valueOf(m.group(1)));
        }
        return null;
    }

    private static Integer monthIndex(String name) {
        for (Integer i = 0; i < MONTHS.size(); i++) {
            if (MONTHS[i] == name || MONTHS[i].left(3) == name.left(3)) {
                return i + 1;
            }
        }
        return null;
    }

    private static Date safeDate(Integer y, Integer mo, Integer d) {
        if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 1871) {
            return null;
        }
        try {
            return Date.newInstance(y, mo, d);
        } catch (Exception e) {
            return null;
        }
    }
}
