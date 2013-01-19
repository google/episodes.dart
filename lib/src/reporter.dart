// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of episodes;

/**
 * Reporter is a class for episode data reporters that need to
 * communicate the performance data to a remote listener via
 * HTTP GETs.
 * Reporter listens for messages from Episodes.dart, and captures
 * the data. When it gets a done message it wraps the data in an
 * URL and attaches that to an Image.src (to get around cross-domain
 * restrictions).
 *
 * To use this, you would typically have a line like this:
 *
 * reporter = new Reporter(baseUrl, urlFormatter, mycallback);
 *
 * Note that apart from creating the reporter, you do not need to
 * explictly call any methods on it, but you would need a keep a
 * reference to it so it does not get garbage collected.
 */

class Reporter {

  static final String version = '0.2';  // episodes version

  // _marks, _measures and _starts are the same as in Episodes.dart
  // except they are extracted from posted messages.

  /** [_marks] holds the timing marks. It maps (mark name => time). */
  Map _marks;

  /**
   * [_measures] holds the timing interval (episode) durationsw.
   * It maps (episode name => duration).
   */
  Map _measures;

  /**
   * [_starts] holds the timing interval (episode) starts.
   * It maps (episode name => start time).
   */
  Map _starts;

  /**
   * [_baseUrl] is the URL to use for the Image GET (typically
   * excluding the parameters). It is passed to the url
   * formatter.
   */
  String _baseUrl;  // E.g. '/images/beacon.gif

  /** We need a method/function to format the image url appropriately;
   * [_urlFormatter] has a reference to that.
   */
  var _urlFormatter;

  /**
   * [img] is a reference to the image element used for HTTP GET. We
   * keep a reference to avoid issues with the image being prematurely
   * garbage collected. Only one reference is kept so the user of the
   * library is responsible for not calling done() multiple times
   * without keeping track of whether previous calls completed, which
   * can be done by providing a [_doneCallback] function in the
   * constructor.
   */
  ImageElement img;

  /**
   * [_doneCallback] is an optional user-supplied callback function
   * that gets called after the IMG beacon GET is complete. It takes
   * the IMG url as a parameter.
   */

  var _doneCallback;

  /**
   *  [_url] is used to record the Image URL that was used to report the
   * performance statistics about. We keep this so we can pass it as a
   * parameter in the user-supplied callback.
   */
  String _url;

  /**
   * The Reporter constructor takes several arguments: the [baseUrl]
   * for the Image element for reporting results to a remote listener
   * via HTTP GET, a reference to a [urlFormatter] function that
   * formats the full Image url with the performance parameters, and
   * and optional [doneCallback] function reference that will be called
   * after the GET is complete (which would typically be used to clear
   * the old marks and episodes).
   */
  Reporter(String baseUrl, [urlFormatter, doneCallback])
      : _baseUrl = baseUrl,
        _urlFormatter = urlFormatter,
        _doneCallback = doneCallback {
    if (_urlFormatter == null) {
      _urlFormatter = _defaultUrlFormatter;
    }
    _marks = new Map();
    _measures = new Map();
    _starts = new Map();

    // Add an event listener for episodes messages.
    window.on.message.add(_handleEpisodeMessage);
  }

  /**
   * _handleEpisodeMessage is the listener for the Episodes
   * window.postMessage events. It uses the contents of these
   * messages to replicate a copy of the _marks, _starts and
   * _measures data that the Episodes class collects.
   */
  void _handleEpisodeMessage(e) {
    var message = e.data;
    // Split the message on ':' and make sure the prefix is EPISODES.
    var aParts = message.split(':');
    if (aParts[0] == PREFIX) {
      var action = aParts[1];

      if (action == INIT) {
        _marks.clear();
        _measures.clear();
        _starts.clear();
      } else if (action == MARK) {
        var markName = aParts[2];
        if (null != aParts[3]) {
          _marks[markName] = int.parse(aParts[3]);
        } else {
          _marks[markName] = new Date.now().millisecondsSinceEpoch;
        }
      } else if (action == MEASURE) {
        var episodeName = aParts[2];
          var startMarkName = ((aParts.length >= 4 && null != aParts[3]) ?
              aParts[3] : episodeName );

        var startEpochTime;
        if (null != _marks[startMarkName]) {
          startEpochTime = _marks[startMarkName];
        } else if (null != startMarkName) {
          startEpochTime = int.parse(startMarkName);
        } else {
          startEpochTime = null;
        }

        var endEpochTime;
        if (aParts.length < 5 || aParts[4] == null) {
          endEpochTime = new Date.now().millisecondsSinceEpoch;
        } else if (null != _marks[aParts[4]]) {
          endEpochTime = _marks[aParts[4]];
        } else {
          endEpochTime = int.parse(aParts[4]);
        }

        if (null != startEpochTime) {
          _starts[episodeName] = startEpochTime;
          _measures[episodeName] = endEpochTime - startEpochTime;
        }
      } else if (action == CLEAR_MARK) {
        var markName = aParts[2];
        _marks.remove(markName);
      } else if (action == CLEAR_EPISODE) {
        var episodeName = aParts[2];
        _starts.remove(episodeName);
        _measures.remove(episodeName);
      } else if (action == CLEAR_ALL_EPISODES) {
        _starts.clear();
        _measures.clear();
      } else if (action == CLEAR_ALL_MARKS) {
        _marks.clear();
      } else if (action == DONE) {
        var url = _sendBeacon();
        print('_handleEpisodeMessage DONE: ${url}');
      }
    }
  }

  /**
   * _defaultUrlFormatter is a simple default Episodes result formatter.
   * It uses the same format as the default episodes.js library. Like
   * all formatters, it takes several arguments: the [_baseUrl] to use
   * for the image URL, the [_markData] timing marks, the [_startData]
   * episode start times, and the [_measureData] episode durations.
   */
  String _defaultUrlFormatter(
        String baseUrl,
        Map markData,
        Map startData,
        Map measureData) {
    var times = new StringBuffer();
    var sep = '';
    for (var key in measureData.keys) {
      times.add('${sep}${encodeUriComponent(key)}:${measureData[key]}');
      sep = ',';
    }
    return '${baseUrl}?ets=${times}&v=${version}';
  }

  /**
   * _onImageLoad is the handler for load succeed/fail of the Image
   * we use for sending results. It nulls the reference to the Image
   * so it can be garbage collected and calls the user-supplied
   * callback if there is one.
   */
  void _onImageLoad(e) {
    img = null;
    if (null != _doneCallback) {
      _doneCallback(_url);
    }
  }

  /**
   * _sendBeacon sends the results to some remote listener via HTTP GET.
   * It uses an Image.url to get around XSS restrictions.
   */
  String _sendBeacon() {
    _url = _urlFormatter(_baseUrl, _marks, _starts, _measures);
    img = new Element.tag('img');
    img.on.load.add(_onImageLoad);
    img.on.error.add(_onImageLoad);
    return img.src = _url;
  }
}
