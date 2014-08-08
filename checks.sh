/root/git/sigma/domain_check.pl > /tmp/sigma_found.log_tmp
/root/git/sigma/ip_check.pl >> /tmp/sigma_found.log_tmp
/root/git/sigma/scanner_check.pl >> /tmp/sigma_found.log_tmp
/root/git/sigma/user_agent_check.pl >> /tmp/sigma_found.log_tmp
/root/git/sigma/email_address_check.pl >> /tmp/sigma_found.log_tmp
mv -f /tmp/sigma_found.log_tmp /tmp/sigma_found.log
