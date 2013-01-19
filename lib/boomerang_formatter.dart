// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Exposes the logic to build an episodes' reporter that sends messages to a
 * boomerang server.
 *
 * To use this, you would typically have a line like this:
 *
 *     reporter = new Reporter(baseUrl, boomerangUrlFormatter, mycallback);
 */
library episodes.boomerang_formatter;

import 'dart:html';

import 'src/constants.dart';

/** Translates Episodes names to Boomerang names. */
Map<String,String> _boomRemap = (() {
  // We use this lazy initialization pattern because const strings can't be used
  // as keys on map literals.
  var map = {};
  map[NAVIGATION_START] = 'nt_nav_st';
  map[REDIRECT_START] = 'nt_red_st';
  map[REDIRECT_END] = 'nt_red_end';
  map[FETCH_START] = 'nt_fet_st';
  map[DOMAIN_LOOKUP_START] = 'nt_dns_st';
  map[DOMAIN_LOOKUP_END] = 'nt_dns_end';
  map[CONNECT_START] = 'nt_con_st';
  map[CONNECT_END] = 'nt_con_end';
  map[REQUEST_START] = 'nt_req_st';
  map[RESPONSE_START] = 'nt_res_st';
  map[RESPONSE_END] = 'nt_res_end';
  map[DOM_LOADING] = 'nt_domloading';
  map[DOM_INTERACTIVE] = 'nt_domint';
  map[DOM_CONTENT_LOADED_EVENT_START] = 'nt_domcontloaded_st';
  map[DOM_CONTENT_LOADED_EVENT_END] = 'nt_comcontloaded_end';
  map[DOM_COMPLETE] = 'nt_domcomp';
  map[LOAD_EVENT_START] = 'nt_load_st';
  map[LOAD_EVENT_END] = 'nt_load_end';
  map[UNLOAD_EVENT_START] = 'nt_unload_st';
  map[UNLOAD_EVENT_END] = 'nt_unload_end';
  return map;
})();

/**
 * URL formatter that uses [Yahoo Boomerang format][doc]. [baseUrl] is where we
 * will be sending results via GET. [marks] is the set of time marks created by
 * mark() calls. [starts] is the measure() interval starts, and [measures] is
 * the measure() interval durations.
 *
 * [doc]: http://yahoo.github.com/boomerang/doc/.
 */
String boomerangUrlFormatter(String baseUrl,
                             Map marks,
                             Map starts,
                             Map measures) {
  final BOOMERANG_VERSION = 1;
  String params;
  if (window.performance != null) {
    params = '&nt_red_cnt=${window.performance.navigation.redirectCount}'
             '&nt_nav_type=${window.performance.navigation.type}';
  } else {
    params = '';
  }

  for (String markName in _boomRemap.keys) {
    var markTime = marks[markName];
    if (markTime != null && markTime != 0) {
      params = '${params}&${_boomRemap[markName]}=${markTime}';
    }
  }
  return '${window.location.protocol}//${baseUrl}?'
        'v=${BOOMERANG_VERSION}&u=${window.location}${params}';
}
