CREATE TABLE "event" ("id" INTEGER PRIMARY KEY  NOT NULL , "data" TEXT NOT NULL , "packDownloaded" BOOL NOT NULL  DEFAULT 0);
CREATE TABLE "kv" ("key" VARCHAR(256) PRIMARY KEY  NOT NULL , "value" TEXT NOT NULL );
CREATE TABLE "localScore" ("key" VARCHAR(256) PRIMARY KEY  NOT NULL , "data" TEXT);
CREATE TABLE "pack" ("id" INTEGER PRIMARY KEY  NOT NULL , "data" TEXT NOT NULL );
