// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library episodes.src.constants;

// Some string constants for windows.postMessage

const String PREFIX = 'EPISODES';
const String MARK = 'mark';
const String MEASURE = 'measure';
const String CLEAR_MARK = 'clearMark';
const String CLEAR_ALL_MARKS = 'clearAllMarks';
const String CLEAR_EPISODE = 'clearEpisode';
const String CLEAR_ALL_EPISODES = 'clearAllEpisodes';
const String INIT = 'init';
const String DONE = 'done';

// Some predefined mark names

const String FIRST_BYTE = 'firstbyte';
const String START_TIME = 'starttime';
const String BACK_END = 'backend';
const String FRONT_END = 'frontend';
const String ON_LOAD = 'onload';
const String TOTAL_TIME = 'totaltime';
const String PAGE_LOAD_TIME = 'pageloadtime';

// Marks and episodes from windows.performance.timing

const String DOM_COMPLETE = '_domComplete';
const String DOM_INTERACTIVE = '_domInteractive';
const String DOM_LOADING = '_domLoading';

const String FETCH = '_fetch';
const String FETCH_START = '_fetchStart';
const String FETCH_END = '_fetchEnd';

const String NAVIGATION = '_navigation';
const String NAVIGATION_START = '_navigationStart';
const String NAVIGATION_END = '_navigationEnd';

const String SECURE_CONNECTION = '_secureConnection';
const String SECURE_CONNECTION_START = '_secureConnectionStart';
const String SECURE_CONNECTION_END = '_secureConnectionEnd';

const String CONNECT = '_connect';
const String CONNECT_START = '_connectStart';
const String CONNECT_END = '_connectEnd';

const String DOMAIN_LOOKUP = '_domainLookup';
const String DOMAIN_LOOKUP_START = '_domainLookupStart';
const String DOMAIN_LOOKUP_END = '_domainLookupEnd';

const String DOM_CONTENT_LOADED_EVENT = '_domContentLoadedEvent';
const String DOM_CONTENT_LOADED_EVENT_START = '_domContentLoadedEventStart';
const String DOM_CONTENT_LOADED_EVENT_END = '_domContentLoadedEventEnd';

const String LOAD_EVENT = '_loadEvent';
const String LOAD_EVENT_START = '_loadEventStart';
const String LOAD_EVENT_END = '_loadEventEnd';

const String REDIRECT = '_redirect';
const String REDIRECT_START = '_redirectStart';
const String REDIRECT_END = '_redirectEnd';

const String REQUEST = '_request';
const String REQUEST_START = '_requestStart';
const String REQUEST_END = '_requestEnd';

const String RESPONSE = '_response';
const String RESPONSE_START = '_responseStart';
const String RESPONSE_END = '_responseEnd';

const String UNLOAD_EVENT = '_unloadEvent';
const String UNLOAD_EVENT_START = '_unloadEventStart';
const String UNLOAD_EVENT_END = '_unloadEventEnd';
