<?php

  // configuration of user and domain
  $user_domain = array();
  // main domain for dynamic DNS
  $dyndns = "";

  $ip_white = array();
  $ip_grey = array();
  $ip_black = array();
  $user_white = array();
  $user_grey = array();
  $user_black = array();

  include 'config.php';

  // short sanity check for given IP
  function checkip($ip)
  {
    $iptupel = explode(".", $ip);
    foreach ($iptupel as $value)
    {
      if ($value < 0 || $value > 255)
        return false;
      }
    return true;
  }

  // retrieve IP
  $ip = $_SERVER['REMOTE_ADDR'];

  // retrieve user
  if ( isset($_SERVER['REMOTE_USER']) )
  {
  	$user = $_SERVER['REMOTE_USER'];
  }
  else if ( isset($_SERVER['PHP_AUTH_USER']) )
  {
    $user = $_SERVER['PHP_AUTH_USER'];
  }
  else
  {
    syslog(LOG_WARN, "No user given by connection from $ip");
    exit(0);
  }

  // open log session
  openlog("DDNS-Provider", LOG_PID | LOG_PERROR, LOG_LOCAL0);

  // check for given domain
  if ( isset($_POST['DOMAIN']) )
  {
    $subdomain = $_POST['DOMAIN'];
  }
  else if ( isset($_GET['DOMAIN']) )
  {
    $subdomain = $_GET['DOMAIN'];
  }
  else
  {
    syslog(LOG_WARN, "User $user from $ip didn't provide any domain");
    exit(0);
  }

  // check for needed variables
  if ( isset($subdomain) && isset($ip) && isset($user) )
  {
		// short sanity check for given IP
    if ( preg_match("/^(\d{1,3}\.){3}\d{1,3}$/", $ip) && checkip($ip) && $ip != "0.0.0.0" && $ip != "255.255.255.255" )
    {
			// short sanity check for given domain
      if ( preg_match("/^[\w\d-_\*\.]+$/", $subdomain) )
      {
				// check whether user is allowed to change domain
        if ( in_array("*", $user_domain[$user]) or in_array($subdomain, $user_domain[$user]) )
        {
          if ( $subdomain != "-" )
            $subdomain = $subdomain . '.';
          else
            $subdomain = '';

          // shell escape all values
          $subdomain = escapeshellcmd($subdomain);
          $user = escapeshellcmd($user);
          $ip = escapeshellcmd($ip);

          // prepare command
          $data = "<<EOF
zone $dyndns
update delete $subdomain$user.$dyndns A
update add $subdomain$user.$dyndns 300 A $ip
send
EOF";
          // run DNS update
          exec("/usr/bin/nsupdate -k /etc/named/Kandrwe.org.+165+24818.private $data", $cmdout, $ret);
          // check whether DNS update was successful
          if ($ret != 0)
          {
            syslog(LOG_INFO, "Changing DNS for $subdomain$user.$dyndns to $ip failed with code $ret");
          }
        }
        else
        {
          syslog(LOG_INFO, "Domain $subdomain is not allowed for $user from $ip");
        }
      }
      else
      {
        syslog(LOG_INFO, "Domain $subdomain for $user from $ip with $subdomain was wrong");
      }
    }
    else
    {
      syslog(LOG_INFO, "IP $ip for $user from $ip with $subdomain was wrong");
    }
  }
  else
  {
    syslog(LOG_INFO, "DDNS change for $user from $ip with $subdomain failed because of missing values");
  }
  // close log session
  closelog();
?>
# vim:ts=2:et
