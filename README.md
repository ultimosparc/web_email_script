# web_email_script
Based on the github project https://github.com/LukeSmithxyz/emailwiz I have delveloped a overall installation script which installs a nginx server as webserver and postfix as email server on any Debian or Ubuntu maschine within few minutes. In addition to the core features by emailwiz

    - **Postfix** to send and receive mail.
    - **Dovecot** to get mail to your email client (mutt, Thunderbird, etc.).
    - Config files that link the two above securely with native log-ins.
    - **Spamassassin** to prevent spam and allow you to make custom filters.
    - **OpenDKIM** to validate you so you can send to Gmail and other big sites.

the script has the following features: 
    
    install automatically all software which you need
    setup automatically nginx as webserver
    validate your new domain and customize your webserver with all domains and subdomains
    create the adminstrator mail account and install automatically all TSL certificates and cronjobs
    create DNS records for your registrar

Remarks:

    You need a Debian or Ubuntu server. 
    The IP of your maschine is connected with your DNS address
    For any issue with the email server, check out https://github.com/LukeSmithxyz/emailwiz



