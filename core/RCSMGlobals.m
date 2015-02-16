//
//  RCSMGlobals.m
//  RCSMac
//
//  Created by Massimo Chiodini on 8/13/12.
//  Copyright 2012 HT srl. All rights reserved.
//

#import "RCSMGlobals.h"


// old binary strings
//char gLogAesKey[]         = "3j9WmmDgBqyU270FTid3719g64bP4s52"; // default
//char gConfAesKey[]        = "Adf5V57gQtyi90wUhpb8Neg56756j87R"; // default
//char gInstanceId[]        = "bg5etG87q20Kg52W5Fg1";
//char gBackdoorID[]        = "av3pVck1gb4eR2d8"; // default
//char gBackdoorSignature[] = "f7Hk0f5usd04apdvqw13F5ed25soV5eD"; //default

  char gLogAesKey[]         = "WfClq6HxbSaOuJGaH5kWXr7dQgjYNSNg"; 
  char gConfAesKey[]        = "6uo_E0S4w_FD0j9NEhW2UpFw9rwy90LY"; 
  char gBackdoorID[]        = "EMp7Ca7-fpOBIrXX";                 // last "XX" for string terminating in rcsmmain.m
  char gBackdoorSignature[] = "ANgs9oGFnEL_vxTxe9eIyBx5lZxfd6QZ"; 
  char gBackdoorPseduoSign[]= "B3lZ3bupLuI4p7QEPDgNyWacDzNmk1pW"; // watermark

  // Demo marker: se la stringa e' uguale a "hxVtdxJ/Z8LvK3ULSnKRUmLE"
  // allora e' in demo altrimenti no demo.
  char gDemoMarker[] = "Pg-WaVyPzMMMMmGbhP6qAigT";

  u_int gVersion     = 2014120801;

char infoPlaceHolder[] =  "20b25555f79c5549094bfd867fe75d004871f3854be8323fbb07381cd5777ae4" \
                          "c19f70723db754b7374e697113583c42550a470f87488de5381af20126e4ce02" \
                          "45151800f8038996d800fd987c7666dece748f6df7e98cde7499c1402de33420" \
                          "0c9a3f4b098e5f88453fab282e49d3d51b7fd3aed73d6ed786f7792a607db2fb";