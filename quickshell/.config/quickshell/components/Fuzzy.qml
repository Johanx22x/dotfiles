// Subsequence matching with a score, the way fzf does it.
//
// WHY NOT THE LAUNCHER'S MATCHER. Launcher.qml ranks with three buckets --
// starts-with, contains, keyword-contains -- which is right for application
// names, where you know what the thing is called and type the first letters
// of it. Settings are not like that: nobody remembers whether the row is
// called "Default timeout" or "Notification timeout", and a substring match
// on "nottime" finds neither. A subsequence match finds both.
//
// The scoring is deliberately simple, and these are the rules in order of how
// much they are worth:
//
//   - a match at the start of a word beats one in the middle of it, because
//     that is where people type from ("dop" should find "Desktop opacity",
//     and it should beat something that merely contains d, o and p);
//   - runs beat scattered letters, so "time" beats "t-i-m-e" spread across
//     three words;
//   - shorter targets win ties, so "Bar" beats "Bar behaviour" for "bar".
//
// It is NOT a general-purpose ranker and it does not try to be Levenshtein:
// there is no tolerance for typos here. A wrong letter means no match, which
// for a list of forty rows is the honest answer -- the alternative is a list
// that always has something in it however badly you type, which is worse than
// an empty one.

pragma Singleton

import QtQuick

QtObject {
    id: root

    // Match `query` against `text`. Returns a score, higher is better, or -1
    // when the query is not a subsequence of the text at all.
    //
    // Case-insensitive, and spaces in the query are ignored entirely: "dop"
    // and "d op" ask the same question.
    function score(text: string, query: string): int {
        if (!query)
            return 0;
        if (!text)
            return -1;

        const haystack = text.toLowerCase();
        const needle = query.toLowerCase().replace(/\s+/g, "");
        if (!needle)
            return 0;

        let total = 0;
        let at = 0;
        let run = 0;

        for (const letter of needle) {
            const found = haystack.indexOf(letter, at);
            if (found < 0)
                return -1;

            // A word start is the first character, or anything after a space,
            // a dash or a slash. Bonus is large enough that an initials match
            // ("dop") outranks a dense mid-word one.
            const atWordStart = found === 0 || " -/_".includes(haystack[found - 1]);
            if (atWordStart)
                total += 12;

            // Consecutive with the previous match: worth more the longer the
            // run gets, so a whole word matched intact dominates.
            run = found === at ? run + 1 : 0;
            total += run * 4;

            // Every skipped character costs a little. Small, or a long label
            // with the letters in it would always lose to a short one that
            // happens to contain them by accident.
            total -= Math.min(found - at, 8);

            at = found + 1;
        }

        // Ties broken towards the shorter label.
        return total - Math.floor(haystack.length / 8);
    }

    // The best score across several fields, so a row can be found by its own
    // label, by the section it sits in or by a keyword none of them mention.
    function scoreAny(fields: var, query: string): int {
        let best = -1;
        for (const field of fields) {
            if (!field)
                continue;
            const value = root.score(String(field), query);
            if (value > best)
                best = value;
        }
        return best;
    }
}
