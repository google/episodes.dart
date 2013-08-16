// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library implements an Episodes-like performance/latency
 * measuring system. See [1] for more about the design of the original
 * Javascript Episodes library.
 *
 * To use, an instance of the Episodes class needs to be created
 * (typically either as a top-level static or in the main()
 * function). The user can then instrument code with calls to
 * mark() and measure(), to mark points in time or record intervals
 * between two such points, respectively. The results
 * can be extracted as a graphical timeline in HTML, as
 * HTML tables, or be communicated to a listener via
 * window.postMessage.
 *
 * Even without explicit instrumentation, the library will record
 * some performance measures. These include the ones from
 * window.performance.timing, if available, as well as these marks:
 *
 *     * starttime - the approximate time when the browser started
 *     * firstbyte - the approximate time when the DOM started loading
 *     * onload - the time when the window.on.load event fired
 *     * done - the time when done() was called or onload happened, whichever
 *       comes first
 *
 * and these episodes:
 *
 *     * backend - starttime..firstbyte
 *     * frontend - firstbyte..onload
 *     * pageloadtime - starttime..onload
 *     * totaltime - starttime..done
 *
 * Episode durations are in milliseconds. Marks are in milliseconds
 * from some epoch; in general it is the relative times and time
 * differences that are more important than the absolute values.
 *
 * There is an associated Reporter class for listening to the
 * window.postMessage notifications. This can be customized in
 * suitable ways. For example, the default case is like the
 * original episodes library; there is also a Yahoo
 * Boomerang compatible reporter available [2].
 *
 * [1]: http://stevesouders.com/episodes/
 * [2]: http://yahoo.github.com/boomerang/doc/
 */
library episodes;

import 'dart:html';

import 'src/constants.dart';
part 'src/reporter.dart';

var mainEpisode = new Episodes();

class Episodes {

 /**
  * [_targetOrigin] is used as the origin parameter
  * calls to window.postMessage.
  */
  String _targetOrigin;

 /**
  * [_marks] holds the set of recorded points in time that
  * are of interest. It maps names to times (in milliseconds).
  * These would typically be measured from the epoch in UTC, but
  * the absolute values are not of much interest; it is the
  * relative values (intervals) that are of interest.
  */
  Map _marks;

 /**
  * [_measures] holds a set of intervals of interest. It maps
  * names to elapsed time (in milliseconds).
  */
  Map _measures;

 /**
  * [_starts] holds the start times of the intervals. This is
  * useful to tell when the intervals occurred with respect to
  * each other. It maps interval names to start times.
  */
  Map _starts;

 /**
  * [_postMessages] is a flag to control whether to use
  * window.postMessage to communicate the marks and measures
  * to a listener (see the Reporter class for a listener
  * implementation). If this is false, then we would typically
  * use dumpEpisodes or dumpMarks to get the performance data.
  */
  bool _postMessages;

 /**
  * [_autorun] controls whether or not we will automatically call
  * done() when window.on.load fires.
  */
  bool _autorun;

 /**
  * [_includePerfMarks] controls whether or not to create a set of
  * marks and intervals (episodes) from the window.performance.timing
  * statistics.
  */
  bool _includePerfMarks;

 /** [_debug] controls whether or not to print debug logs.  */
  bool _debug;

 /**
  * To use the library an instance of the Episodes class
  * should be created. This can include the initial values for
  * [postMessages], [includePerfMarks], [autorun] and [debug].
  * The constructor will attempt to find the 'firstbyte' time
  * mark value and the 'starttime' mark value; the former is an
  * approximation of the time when the first page started loading
  * and the latter is an approximation of the time when the
  * current page started loading.
  */
  Episodes([
      bool postMessages = true,
      bool includePerfMarks = true,
      bool autorun = false,
      bool debug = false])
      : _postMessages = postMessages,
        _includePerfMarks = includePerfMarks,
        _autorun = autorun,
        _debug = debug {
    _targetOrigin =
        '${window.location.protocol}//'
        '${window.location.hostname}:${window.location.port}';
    // If we're running locally we can get a file://-style target
    // origin which can blow up window.postMessage, so fix that.
    if (_targetOrigin.startsWith('file://')) {
      _targetOrigin = '*';
    }
    _marks = {};
    _measures = {};
    // We need to save the starts so that given a measure we can
    // say the epoch times that it began and ended.
    _starts = {};
    // Get the start time. This can come from
    // a cookie, or from window.performance.timing.
    var startTime = findStartTime();

    // Get the first byte time. We typically try to get this
    // from the head element's id, assuming the user has inserted the necessary
    // script fragment as the first child of the <head> element tag:
    //     <script type="application/javascript">
    //       document.head.id = new Date().getTime();
    //     </script>
    var firstbyte;
    try {
      // This throws an exception in Opera, hence the try/catch.
      firstbyte = document.head.id;
    } catch (e) {
      firstbyte = null;
    }

    // If we failed to get firstbyte from the DOM, use startTime
    if (firstbyte == null) {
        firstbyte = startTime;
    } else {
      // convert the string to an int
      try {
        firstbyte = _paramToInt(firstbyte);
      } catch (e) {
        firstbyte = startTime;
      }
    }
    mark(FIRST_BYTE, firstbyte);

    try {
      // Opera throws an exception here as it does not support these
      // Surely Dart should hide this, or try implement JS versions of this?
      window.onBeforeUnload.listen(_beforeUnload);
      // Note - this could happen AFTER the load event has already fired!!
      window.onLoad.listen(_onload);
    } catch (e) {
    }
  }

  /**
   * mark() sets a time marker (typically the beginning of an episode).
   * [markName] is a name to associate with the mark, and [markTime],
   * if included, is the time to use. If [markTime] is not specified
   * (which would be typical) then the current time is used.
   * mark() also creates the predefined episodes 'backend',
   * 'frontend', 'pageloadtime' and 'totaltime' when their endpoints
   * are marked.
   */
  void mark(String markName, [markTime = null]) {
    if (_debug) {
      print('${PREFIX}:${MARK}:${markName}:${markTime}');
    }

    if (markName == null) {
      print('Error: markName is undefined in mark()');
      return;
    }
    if (markTime == null) {
      markTime = new DateTime.now().millisecondsSinceEpoch;
    } else if (markTime is! int) {
      try {
        // Make sure the time is a number.
        markTime = _paramToInt(markTime);
      } catch (e) {
        print('Error: malformed time ${markTime}');
        return;
      }
    }

    // Unsupported or irrelevant times from window.performance.timing
    // typically have a zero value, so to avoid creating extraneous
    // marks we guard against this.
    if (markTime == 0) return;

    _marks[markName] = markTime;

    if (_postMessages) {
      window.postMessage('${PREFIX}:${MARK}:${markName}:${markTime}',
        _targetOrigin);
    }

    // Upon getting certain special marks we create some special episodes.
    if (markName == FIRST_BYTE) {
      measure(BACK_END, START_TIME, FIRST_BYTE);
    } else if (markName == ON_LOAD) {
      measure(FRONT_END, FIRST_BYTE, ON_LOAD);
      measure(PAGE_LOAD_TIME, START_TIME, ON_LOAD);
    } else if (markName == DONE) {
      measure(TOTAL_TIME, START_TIME);
    }
  }

 /**
  * measure() records an episode with the name [episodeName].
  * If [startNameOrTime] is specified, it should be either the
  * name of an existing mark, or a time, and similarly for
  * [endNameOrTime]. If either of these are not specified, they
  * default to the current time.
  */
  void measure(String episodeName,
      [startNameOrTime = null, endNameOrTime = null]) {
    int now = new DateTime.now().millisecondsSinceEpoch;
    if (_debug) {
      print('${PREFIX}:${MEASURE}:'
            '${episodeName}:${startNameOrTime}:${endNameOrTime}');
    }
    if (episodeName == null) {
      print('Error: episodeName is undefined in measure().');
      return;
    }
    int startEpochTime;
    if (startNameOrTime == null) {
      // If no startName is specified, use the episodeName as the start mark.
      startEpochTime = _marks[episodeName];
      if (startEpochTime == null) {
        // No time specified; use the current time.
        startEpochTime = now;
      }
    } else {
      // If a mark with this name exists, use that.
      startEpochTime = _marks[startNameOrTime];
      if (startEpochTime == null) {
        // Assume a specific epoch time is provided.
        startEpochTime = _paramToInt(startNameOrTime);
      }
    }
    int endEpochTime;
    if (endNameOrTime == null) {
      endEpochTime = now;
    } else if (_marks[endNameOrTime] != null) {
      // If a mark with this name exists, use that.
      endEpochTime = _marks[endNameOrTime];
    } else {
      endEpochTime = _paramToInt(endNameOrTime);
    }
    _starts[episodeName] = startEpochTime;
    _measures[episodeName] = endEpochTime - startEpochTime;
    if (_postMessages) {
      window.postMessage('${PREFIX}:${MEASURE}:${episodeName}:'
            '${startEpochTime}:${endEpochTime}', _targetOrigin);
    }
  }

  /** clearMark clears the mark with name [markName], if it exists. */
  void clearMark(String markName) {
    if (_debug) {
      print('${PREFIX}:${CLEAR_MARK}:${markName}');
    }
    _marks.remove(markName);
    if (_postMessages) {
      window.postMessage('${PREFIX}:${CLEAR_MARK}:${markName}',
        _targetOrigin);
    }
  }

  /**
   * clearEpisode clears the episode with name [episodeName], if
   * it exists. It does not change the marks.
   */
  void clearEpisode(String episodeName) {
    if (_debug) {
      print('${PREFIX}:${CLEAR_EPISODE}:${episodeName}');
    }
   _starts.remove(episodeName);
   _measures.remove(episodeName);
   if (_postMessages) {
     window.postMessage('${PREFIX}:${CLEAR_EPISODE}:${episodeName}',
        _targetOrigin);
   }
  }

  /** clearAllMarks removes all marks but not the episodes. */
  void clearAllMarks() {
    if (_debug) {
      print('${PREFIX}:${CLEAR_ALL_MARKS}');
    }
    _marks.clear();
    if (_postMessages) {
      window.postMessage('${PREFIX}:${CLEAR_ALL_MARKS}', _targetOrigin);
    }
  }

  /** clearAllEpisodes clears all episodes, but does not change marks. */
  void clearAllEpisodes() {
    if (_debug) {
      print('${PREFIX}:${CLEAR_ALL_EPISODES}');
    }
    _starts.clear();
    _measures.clear();
    if (_postMessages) {
      window.postMessage('${PREFIX}:${CLEAR_ALL_EPISODES}', _targetOrigin);
    }
  }

  /** clearAll removes all marks and all episodes. */
  void clearAll() {
    if (_debug) {
      print('${PREFIX}:${INIT}');
    }
    clearAllMarks();
    clearAllEpisodes();
    if (_postMessages) {
      window.postMessage('${PREFIX}:${INIT}', _targetOrigin);
    }
  }

 /** getMark returns the time associated with the mark named [markName],
  *  in milliseconds from the epoch.
  */
  int getMark(String markName) {
    return _marks[markName];
  }

  /**
   * getEpisodeStart gets the start time of a specific episode,
   * whose name is specified by [episodeName], in milliseconds
   * from the epoch.
   */
  int getEpisodeStart(String episodeName) {
    return _starts[episodeName];
  }

  /**
   * getEpisodeDuration gets the duration of a specific episode
   * in milliseconds, whose name is specified by [episodeName].
   */
  int getEpisodeDuration(String episodeName) {
    return _measures[episodeName];
  }

  /**
   * In the case of Ajax or post-onload episodes, call done to
   * signal the end of the episodes. This means reporting can start.
   */
  void done() {
    if (_debug) {
      print('${PREFIX}:${DONE}');
    }
    mark(DONE);
    if (_postMessages) {
      window.postMessage('${PREFIX}:${DONE}', _targetOrigin);
    }
  }

  /**
   * findStartTime uses various techniques to try to determine
   * the time at which this page started. If possible it will use
   * window.performance.timing.navigationStart. If that fails it will
   * look for a cookie that we created at the time of a beforeUnload
   * event. If that fails it will use the current time.
   * As a side-effect it creates the 'starttime' mark.
   */
  findStartTime() {
    var startTime = _findStartWebTiming();
    if (startTime == null) {
      startTime = _findStartCookie();
      if (startTime == null) {
        // fall back to now
        startTime = new DateTime.now().millisecondsSinceEpoch;
      }
    }
    mark(START_TIME, startTime);
    return startTime;
  }

  /**
   * _findStartWebTiming tries to get the page start time from
   * the Web Timing "performance" object.
   */
  _findStartWebTiming() {
    var startTime = null;
    if (null != window.performance &&
        null != window.performance.timing.navigationStart) {
      startTime = window.performance.timing.navigationStart;
      print('${PREFIX}.findStartWebTiming: startTime = ${startTime}');
    }
    return startTime;
  }

  /**
   * _findStartCookie tries to get the page start time based
   * on a cookie set by Episodes in the page unload handler.
   */
  _findStartCookie() {
    var cookies = document.cookie.split(' ');
    var marker = '${PREFIX}=';
    for (int i = 0; i < cookies.length; i++) {
      if (cookies[i].startsWith(marker)) {
        var subCookies = cookies[i].substring(marker.length).split('&');
        var startTime, referrerMatch;
        for (int j = 0; j < subCookies.length; j++ ) {
          if (subCookies[j].startsWith('s=')) {
            startTime = subCookies[j].substring(2);
          } else if (subCookies[j].startsWith('r=')) {
            var startPage = subCookies[j].substring(2);
            referrerMatch =
                (Uri.encodeComponent(document.referrer) == startPage);
          }
        }
        if (referrerMatch && startTime) {
          print('${PREFIX}.findStartCookie: startTime = ${startTime}');
          return startTime;
        }
      }
    }
    return null;
  }

  /**
   *  _beforeUnload sets a cookie when the page unloads, with the current
   * time. This cookies is consumed on the next page to get a "start time".
   * This doesn't work in some browsers (Opera).
   */
  void _beforeUnload(unused) {
    document.cookie = '${PREFIX}=s=${new DateTime.now().millisecondsSinceEpoch}&'
         'r=${Uri.encodeComponent(window.location.toString())}; path=/';
  }

  /**
   * _addPair is a utility function to add a pair of marks and
   * an episode given the name and start and end times. We don't do this
   * if the end time is zero as that usually means the times
   * are for a non-event.
   */
  void _addPair(String name, int start, int end) {
    if (end > 0) {
      mark('${name}Start', start);
      mark('${name}End', end);
      measure(name, start, end);
    }
  }

  /**
   * _onload is called by window.on.load to do final wrap-up.
   * It adds an 'onload' mark, potentially creates marks and episodes
   * from the window.performance.timing object, and (if [_autorun] is
   * true) will call the done() handler.
   */
  void _onload(unused) {
    mark(ON_LOAD);

    // Add timings from window.performance if we have them.
    if (_includePerfMarks && window.performance != null) {
      PerformanceTiming tm = window.performance.timing;

      mark(DOM_COMPLETE, tm.domComplete);
      mark(DOM_INTERACTIVE, tm.domInteractive);
      mark(DOM_LOADING, tm.domLoading);
      mark(FETCH_START, tm.fetchStart);
      mark(NAVIGATION_START, tm.navigationStart);
      mark(SECURE_CONNECTION_START, tm.secureConnectionStart);

      _addPair(CONNECT, tm.connectStart, tm.connectEnd);
      _addPair(DOMAIN_LOOKUP, tm.domainLookupStart, tm.domainLookupEnd);
      _addPair(DOM_CONTENT_LOADED_EVENT,
        tm.domContentLoadedEventStart, tm.domContentLoadedEventEnd);
      _addPair(LOAD_EVENT, tm.loadEventStart, tm.loadEventEnd);
      _addPair(REDIRECT, tm.redirectStart, tm.redirectEnd);
      _addPair(REQUEST, tm.requestStart, tm.responseStart);
      _addPair(RESPONSE, tm.responseStart, tm.responseEnd);
      _addPair(UNLOAD_EVENT, tm.unloadEventStart, tm.unloadEventEnd);
    }
    if (_autorun) {
      done();
    }
  }

  /**
   * Creates an HTML table with all the mark data and attaches it to a DOM node
   * specified by [parent]. The table will have a 1 pixel border by default
   * although this can be changed by specifying the <table> tag attributes in
   * the [attributes] parameter.
   */
  void dumpMarks(parent, [String attributes = "border='1'"]) {
    if (parent == null) {
      return;
    }
    // Helper function to dump the Marks.
    var table = new StringBuffer('<table ${attributes}><tbody>');
    table.add('<tr><td>Name</td><td>Time</td></tr>');
    for (var markName in _marks.keys) {
      int when = _marks[markName];
      table.add('<tr><td>${markName}</td><td>${when}</td></tr>');
    }
    table.add('"</tbody></table>');
    parent.innerHTML = table.toString();
  }

  /**
   * Creates an HTML table with all the episode data and attaches it to a DOM
   * node specified by [parent]. The table will have a 1 pixel border by default
   * although this can be changed by specifying the <table> tag attributes in
   * the [attributes] parameter.
   */
  void dumpEpisodes(parent, [String attribs = "border='1'"]) {
    if (parent == null) {
      return;
    }
    // Helper function to dump the Episodes.
    var table = new StringBuffer();
    table.add('<table ${attribs}><tbody><tr><td>Episode</td>');
    table.add('<td>Start</td><td>End</td><td>Duration</td></tr>');
    for (var episodeName in _measures.keys) {
      // we used to check hasOwnProperty but in Dart we shouldn't need it?
      var start = _starts[episodeName];
      var duration = _measures[episodeName];
      var end = start + duration;
      table.add('<tr><td>${episodeName}</td><td>${start}</td>');
      table.add('<td>${end}</td><td>${duration}</td></tr>');
    }
    table.add('</tbody></table>');
    parent.innerHTML = table.toString();
  }

  /**
   * Draws a picture of the Episodes as a graphical timeline. It sets the
   * innerHTML of the [parent] DOM node. [includeMarks] tells whether marks
   * should be drawn; if false only episodes are drawn.
   */
  void drawEpisodes(parent, [bool includeMarks = true]) {
    if (parent == null) return;

    // Put the episodes (and marks) in order by start time and duration.
    // Create an array that we'll sort with special function.
    List aEpisodes = new List(); // Each element is an array: [start, end, name]
    for (var episodeName in _measures.keys) {
      // We used to check hasOwnProperty but in Dart we shouldn't need it?
      var start = _starts[episodeName];
      aEpisodes.add([start, start + _measures[episodeName], episodeName]);
    }
    if (includeMarks) {
      for (var episodeName in _marks.keys) {
        // We used to check hasOwnProperty but in Dart we shouldn't need it?
        if (_measures[episodeName] == null) {
          // Only add the mark if it is NOT an episode.
          var start = _marks[episodeName];
          aEpisodes.add([start, start, episodeName]);
        }
      }
    }
    aEpisodes.sort(_sortEpisodes);

    // Find start and end of all episodes.
    var tFirst = aEpisodes[0][0];
    var tLast = aEpisodes[0][1];
    var len = aEpisodes.length;
    for (var i = 1; i < len; i++ ) {
      if (aEpisodes[i][1] > tLast) {
        tLast = aEpisodes[i][1];
      }
    }

    // Create HTML to represent the episodes.
    var nPixels = parent.clientWidth - 100;
    num PxlPerMs = nPixels / (tLast - tFirst);
    var sHtml = new StringBuffer();
    for (var i = 0; i < aEpisodes.length; i++ ) {
      var start = aEpisodes[i][0];
      var end = aEpisodes[i][1];
      var delta = end - start;
      var episodeName = aEpisodes[i][2];
      int leftPx = ((PxlPerMs * (start - tFirst)) + 40).round();
      int widthPx = (PxlPerMs * delta).round();
      sHtml.write('<div style="font-size: 10pt; position: absolute; '
          'left: ${leftPx}px; top: ${(i*30)}px; width: ${widthPx}px; '
          'height: 16px;"><div style="background: #EEE; border: 1px solid; '
          'padding-bottom: 2px;"><nobr style="padding-left: 4px;">'
          '${episodeName}');
      if (delta > 0) sHtml.write(' ${delta}ms');
      sHtml.write('</nobr></div></div>\n');
    }
    parent.innerHtml = sHtml.toString();
  }

  /**
   * _sortEpisodes is a comparator for items that are made of pairs of
   * (start,end) times. Start time is used as a primary
   * sort key and end time is used as a secondary sort key.
   */
  int _sortEpisodes(a, b) {
    if (a[0] == b[0]) {
      if (a[1] == b[1]) {
        return 0;
      }
      if (a[1] > b[1]) {
        return -1;
      }
      return 1;
    }
    if (a[0] < b[0]) {
      return -1;
    }
    return 1;
  }

  /** _paramToInt turns a user-provided parameter into an int. */
  int _paramToInt(p) {
    if (p is int) {
      return p;
    } else if (p is double) {
      return p.toInt();
    } else {
      return double.parse(p.toString()).toInt();
    }
  }
}
