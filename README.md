# web_email_script
Installation of web and email server

Core features: 
    
    install automatically all software which you need
    setup automatically nginx as webserver
    validate your new domain and customize your webserver with all domains and subdomains
    setup Postfix to send and receive mail
    setup automatically Dovecot to get mail to your email client (mutt, Thunderbird, etc.)
    adjust automatically all config files that link the two above securely with native log-ins
    setup automatically Spamassassin to prevent spam and allow you to make custom filters
    setup automatically OpenDKIM to validate you so you can send to Gmail and other big site
    create the adminstrator mail account and install automatically all TSL certificates and cronjobs
    create DNS records for your registrar

This script does not:

    use a SQL database or anything like that.
    set up a graphical interface for mail like Roundcube or Squirrel Mail. 

Requirements:

    A Debian or Ubuntu server. 

Post-install remarks:

Let's say we want to add a user Billy and let him receive mail, run this:
       
       useradd -m -G mail billy
       passwd billy

A user's mail will appear in ~/Mail/. If you want to see your mail while ssh'd in the server, you could just install mutt, 
add set spoolfile="+Inbox" to your ~/.muttrc and use mutt to view and reply to mail. You'll probably want to log in remotely though:
Logging in from Thunderbird or mutt (and others) remotely

Let's say you want to access your mail with Thunderbird or mutt or another email program. For my domain, the server information will be as follows:

    SMTP server: mail.mywebsite.com
    SMTP port: 587
    IMAP server: mail.mywebsite.com
    IMAP port: 993

Troubleshooting -- Can't send mail?

    Always check journalctl -xe to see the specific problem.
    Check with your VPS host and ask them to enable mail ports. Some providers disable them by default. It shouldn't take any time.
    Go to this site to test your TXT records. If your DKIM, SPF or DMARC tests fail you probably copied in the TXT records incorrectly.
    Check your DNS settings using this site, it'll report any issues with your MX records
    Ensure that port 25 is open on your server. Vultr for instance blocks this by default, you need to open a support ticket with them to open it. 
    You can't send mail if 25 is blocked
