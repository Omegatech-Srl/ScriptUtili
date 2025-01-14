#!/usr/local/bin/php
<?php
require_once("config.inc");
require_once("functions.inc");
require_once("ipsec.inc");

ipsec_configure();
log_error("Tutti i tunnel IPsec sono stati riavviati.");
?>
