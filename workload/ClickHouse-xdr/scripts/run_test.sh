#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ROOT_DIR=/root/clickhouse
cd ${ROOT_DIR}

# Print parameters
echo "CLIENT_CORE_LIST: ${CLIENT_CORE_LIST}"
echo "SERVER_CORE_LIST: ${SERVER_CORE_LIST}"
echo "SERVER_MAX_THREADS: ${SERVER_MAX_THREADS}"

# Run server
taskset -c ${SERVER_CORE_LIST} ./clickhouse server -C ${ROOT_DIR}/config.xml --daemon > ${ROOT_DIR}/server.log 2>&1

echo "Preparing dataset..."
tar -xvf hits_v1.tsv.tgz

echo "Creating database..."
./clickhouse client --query "CREATE DATABASE IF NOT EXISTS datasets"
./clickhouse client --query "CREATE TABLE datasets.hits_v1 ( WatchID UInt64,  JavaEnable UInt8,  Title String,  GoodEvent Int16,  EventTime DateTime,  EventDate Date,  CounterID UInt32,  ClientIP UInt32,  ClientIP6 FixedString(16),  RegionID UInt32,  UserID UInt64,  CounterClass Int8,  OS UInt8,  UserAgent UInt8,  URL String,  Referer String,  URLDomain String,  RefererDomain String,  Refresh UInt8,  IsRobot UInt8,  RefererCategories Array(UInt16),  URLCategories Array(UInt16), URLRegions Array(UInt32),  RefererRegions Array(UInt32),  ResolutionWidth UInt16,  ResolutionHeight UInt16,  ResolutionDepth UInt8,  FlashMajor UInt8, FlashMinor UInt8,  FlashMinor2 String,  NetMajor UInt8,  NetMinor UInt8, UserAgentMajor UInt16,  UserAgentMinor FixedString(2),  CookieEnable UInt8, JavascriptEnable UInt8,  IsMobile UInt8,  MobilePhone UInt8,  MobilePhoneModel String,  Params String,  IPNetworkID UInt32,  TraficSourceID Int8, SearchEngineID UInt16,  SearchPhrase String,  AdvEngineID UInt8,  IsArtifical UInt8,  WindowClientWidth UInt16,  WindowClientHeight UInt16,  ClientTimeZone Int16,  ClientEventTime DateTime,  SilverlightVersion1 UInt8, SilverlightVersion2 UInt8,  SilverlightVersion3 UInt32,  SilverlightVersion4 UInt16,  PageCharset String,  CodeVersion UInt32,  IsLink UInt8,  IsDownload UInt8,  IsNotBounce UInt8,  FUniqID UInt64,  HID UInt32,  IsOldCounter UInt8, IsEvent UInt8,  IsParameter UInt8,  DontCountHits UInt8,  WithHash UInt8, HitColor FixedString(1),  UTCEventTime DateTime,  Age UInt8,  Sex UInt8,  Income UInt8,  Interests UInt16,  Robotness UInt8,  GeneralInterests Array(UInt16), RemoteIP UInt32,  RemoteIP6 FixedString(16),  WindowName Int32,  OpenerName Int32,  HistoryLength Int16,  BrowserLanguage FixedString(2),  BrowserCountry FixedString(2),  SocialNetwork String,  SocialAction String,  HTTPError UInt16, SendTiming Int32,  DNSTiming Int32,  ConnectTiming Int32,  ResponseStartTiming Int32,  ResponseEndTiming Int32,  FetchTiming Int32,  RedirectTiming Int32, DOMInteractiveTiming Int32,  DOMContentLoadedTiming Int32,  DOMCompleteTiming Int32,  LoadEventStartTiming Int32,  LoadEventEndTiming Int32, NSToDOMContentLoadedTiming Int32,  FirstPaintTiming Int32,  RedirectCount Int8, SocialSourceNetworkID UInt8,  SocialSourcePage String,  ParamPrice Int64, ParamOrderID String,  ParamCurrency FixedString(3),  ParamCurrencyID UInt16, GoalsReached Array(UInt32),  OpenstatServiceName String,  OpenstatCampaignID String,  OpenstatAdID String,  OpenstatSourceID String,  UTMSource String, UTMMedium String,  UTMCampaign String,  UTMContent String,  UTMTerm String, FromTag String,  HasGCLID UInt8,  RefererHash UInt64,  URLHash UInt64,  CLID UInt32,  YCLID UInt64,  ShareService String,  ShareURL String,  ShareTitle String,  ParsedParams Nested(Key1 String,  Key2 String, Key3 String, Key4 String, Key5 String,  ValueDouble Float64),  IslandID FixedString(16),  RequestNum UInt32,  RequestTry UInt8) ENGINE = MergeTree() PARTITION BY toYYYYMM(EventDate) ORDER BY (CounterID, EventDate, intHash32(UserID)) SAMPLE BY intHash32(UserID) SETTINGS index_granularity = 8192"

echo "Loading dataset..."
cat hits_v1.tsv | ./clickhouse client --query "INSERT INTO datasets.hits_v1 FORMAT TSV" --max_insert_block_size=100000

echo "Sleeping 10s before starting test..."
sleep 10

# Query settings
query_settings="settings max_threads=${SERVER_MAX_THREADS}"

# Start test
echo "Starting test..."
function run_query() {
    echo "Running query: $1"
    (time -p taskset -c $CLIENT_CORE_LIST ./clickhouse client --query "$2 ${query_settings}") > ${ROOT_DIR}/$1_results.logs 2>&1
}

run_query "query1" "select sum(multiMatchAny(URL, ['/t[0-9]+-', '/questions/7{9}[0-9]+'])) from datasets.hits_v1"
run_query "query2" "select sum(multiMatchAny(URL, ['f[ae]b[ei]rl', 'ф[иаэе]б[еэи][рпл]', 'афиукд', 'a[ft],th','^ф[аиеэ]?б?[еэи]?$', 'берлик', 'fab', 'фа[беьв]+е?[рлко]'])) from datasets.hits_v1"
run_query "query3" "select sum(multiMatchAny(URL, ['/questions/q*', '/q[0-9]*/', '/questions/[0-9]*'])) from datasets.hits_v1"
run_query "query4" "select sum(multiMatchAny(URL, ['//ngs.ru/$', '//m.ngs.ru/$', '//news.ngs.ru/$','//m.news.ngs.ru/$','//ngs.ru/\\?', '//m.ngs.ru/\\?','//news.ngs.ru/\\?', '//m.news.ngs.ru/\\?'])) from datasets.hits_v1"
run_query "query5" "select sum(multiMatchAny(URL, ['[ми][аеэпви][нм][ асзи][иус]*', '[mn][аeauo][nm]s[уyi]*','ru', 'v[ft\']v[cp][be]', 'www', 'ьфьын', 'маиси', 'mam','amsy', 'маммси', 'амси', 'vfvc'])) from datasets.hits_v1"

run_query "query6" "select count() from datasets.hits_v1 where (URL like '%афиукд%') or (URL like '%берлик%') or (URL like '%fab%') or (URL like '%ru%') or (URL like '%www%') or (URL like '%ьфьын%') or (URL like '%маиси%') or (URL like '%mam%') or (URL like '%amsy%') or (URL like '%маммси%') or (URL like '%амси%') or (URL like '%vfvc%') or (URL like '%/t0-%') or (URL like '%/t1-%') or (URL like '%/t2-%') or (URL like '%/questions/7777777770%') or (URL like '%faberl%') or (URL like '%febirl%') or (URL like '%фибер%') or (URL like '%фибеп%') or (URL like '%фибел%') or (URL like '%фибэр%') or (URL like '%фибэп%') or (URL like '%фибэл%') or (URL like '%фибар%') or (URL like '%фибап%') or (URL like '%фибал%') or (URL like '%/q0%') or (URL like '%/q1%') or (URL like '%/q2%') or (URL like '%/q3%') or (URL like '%/q4%') or (URL like '%/q5%') or (URL like '%/questions/0%') or (URL like '%/questions/1%') or (URL like '%/questions/2%') or (URL like '%/questions/3%') or (URL like '%/questions/4%') or (URL like '%/questions/5%')"
run_query "query7" "select count() from datasets.hits_v1 where multiMatchAny(URL,['афиукд','берлик','fab','ru','www','ьфьын','маиси','mam','amsy','маммси','амси','vfvc','/t0-','/t1-','/t2-','/questions/7777777770','faberl','febirl','фибер','фибеп','фибел','фибэр','фибэп','фибэл','фибар','фибап','фибал','/q0','/q1','/q2','/q3','/q4','/q5','/questions/0','/questions/1','/questions/2','/questions/3','/questions/4','/questions/5'])"