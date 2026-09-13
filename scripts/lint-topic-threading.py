#!/usr/bin/env python3
import os
import re
import sys

THREAD_ONLY = 'TGMessageTopicDictionary('
HAND_BUILT = ('"messageTopicForum"', '"messageTopicThread"', '"messageTopicSavedMessages"',
	'"messageTopicDirectMessages"')
OWNER = os.path.join('src', 'TDLibClient', 'TGMessageTopic.m')

ALLOWED_WRAPPERS = {
    'src/TDLibClient/TGClient+Messages.m': ['TGMsgTopic'],
}

def allowed_spans(path, text):
    spans = []
    for name in ALLOWED_WRAPPERS.get(path.replace(os.sep, '/'), []):
        match = re.search(r'static NSDictionary \*%s\([^)]*\)\s*\{.*?\n\}' % re.escape(name), text, re.S)
        if match:
            spans.append((text[:match.start()].count('\n') + 1, text[:match.end()].count('\n') + 1))
    return spans

def offenders_in(path, text):
    spans = allowed_spans(path, text)
    found = []
    for number, line in enumerate(text.split('\n'), 1):
        if any(start <= number <= end for start, end in spans):
            continue
        if THREAD_ONLY in line:
            found.append(f'{path}:{number}: builds a topic from a thread alone; use TGTopicDictionary '
                         'so a saved or direct-messages topic is not dropped')
        if '@"@type" : ' in line and any(kind in line for kind in HAND_BUILT):
            found.append(f'{path}:{number}: names a topic kind by hand; use TGTopicDictionary so the '
                         'kind follows the topic the message is being sent into')
    return found

def self_test():
    sender = '''- (void)sendThing {
	NSDictionary *topic = TGMessageTopicDictionary(threadId, NO);
}
'''
    wrapper = '''static NSDictionary *TGMsgTopic(int64_t threadId, BOOL chatIsForum) {
	return TGMessageTopicDictionary(threadId, chatIsForum);
}
'''
    assert offenders_in('src/TDLibClient/TGClient+Bots.m', sender), 'a bare sender must be reported'
    assert not offenders_in('src/TDLibClient/TGClient+Messages.m', wrapper), 'the allowed wrapper must pass'
    assert offenders_in('src/TDLibClient/TGClient+Bots.m', wrapper), 'the wrapper is allowed in one file only'
    assert not offenders_in('src/TDLibClient/TGClient+Bots.m', '@"topic_id"\n'), 'unrelated code must pass'
    hand = '\trequest[@"topic_id"] = @{@"@type" : @"messageTopicForum"};\n'
    assert offenders_in('src/TDLibClient/TGClient+MessageContent.m', hand), \
        'a hand-named topic kind must be reported'
    print('lint-topic-threading: self-test passed')
    return 0

def main():
    if '--self-test' in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else 'src'
    reported = []
    for base, _, names in os.walk(root):
        for name in names:
            if not name.endswith(('.m', '.mm')):
                continue
            path = os.path.join(base, name)
            if os.path.normpath(path) == OWNER:
                continue
            reported += offenders_in(path, open(path, encoding='utf-8', errors='replace').read())
    if reported:
        for line in reported:
            print('lint-topic-threading:', line)
        return 1
    print('lint-topic-threading: every request builds its topic from the full topic triple')
    return 0

if __name__ == '__main__':
    sys.exit(main())
