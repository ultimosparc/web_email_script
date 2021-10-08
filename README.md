# web_email_script
Installation of web and email server

Remarks: 

When prompted by a dialog menu at the beginning, select "Internet Site", then give your full domain without any subdomain, i.e. mywebsite.com
This script installs

    Postfix to send and receive mail.
    Dovecot to get mail to your email client (mutt, Thunderbird, etc.).
    Config files that link the two above securely with native log-ins.
    Spamassassin to prevent spam and allow you to make custom filters.
    OpenDKIM to validate you so you can send to Gmail and other big sites.

This script does not

    use a SQL database or anything like that.
    set up a graphical interface for mail like Roundcube or Squirrel Mail. 

Requirements

    A Debian or Ubuntu server. 

Post-install requirement!


Making new users/mail accounts

Let's say we want to add a user Billy and let him receive mail, run this:

useradd -m -G mail billy
passwd billy

Any user added to the mail group will be able to receive mail. S

A user's mail will appear in ~/Mail/. If you want to see your mail while ssh'd in the server, you could just install mutt, add set spoolfile="+Inbox" to your ~/.muttrc and use mutt to view and reply to mail. You'll probably want to log in remotely though:
Logging in from Thunderbird or mutt (and others) remotely

Let's say you want to access your mail with Thunderbird or mutt or another email program. For my domain, the server information will be as follows:

    SMTP server: mail.lukesmith.xyz
    SMTP port: 587
    IMAP server: mail.lukesmith.xyz
    IMAP port: 993


Benefited from this?

I am always glad to hear this script is still making life easy for people! If this script or documentation has saved you some frustration, you can donate to support me at 

Troubleshooting -- Can't send mail?

    Always check journalctl -xe to see the specific problem.
    Check with your VPS host and ask them to enable mail ports. Some providers disable them by default. It shouldn't take any time.
    Go to this site to test your TXT records. If your DKIM, SPF or DMARC tests fail you probably copied in the TXT records incorrectly.
    If everything looks good and you can send mail, but it still goes to Gmail or another big provider's spam directory, your domain (especially if it's a new one) might be on a public spam list. Check this site to see if it is. Don't worry if you are: sometimes especially new domains are automatically assumed to be spam temporarily. If you are blacklisted by one of these, look into it and it will explain why and how to remove yourself.
    Check your DNS settings using this site, it'll report any issues with your MX records
    Ensure that port 25 is open on your server. Vultr for instance blocks this by default, you need to open a support ticket with them to open it. You can't send mail if 25 is blocked
