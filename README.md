# web_email_script
Based on the github project https://github.com/LukeSmithxyz/emailwiz and the video https://www.youtube.com/watch?v=3dIVesHEAzc&list=PL-p5XmQHB_JRRnoQyjOfioJdDmu87DIJc&index=10 I developed a overall installation script which installs a nginx server as webserver and postfix as email server on any Debian or Ubuntu maschine within few minutes. In addition to the core features by emailwiz

    - **Postfix** to send and receive mail.
    - **Dovecot** to get mail to your email client (mutt, Thunderbird, etc.).
    - Config files that link the two above securely with native log-ins.
    - **Spamassassin** to prevent spam and allow you to make custom filters.
    - **OpenDKIM** to validate you so you can send to Gmail and other big sites.

the script has the following features: 
    
    - It installs automatically all software which you need. 
    - It setups automatically nginx as webserver. 
    - It validates your new domain and customizes your webserver with all domains and subdomains. 
    - It creates the first mail account and installs all TSL certificates and cronjobs.  
    - It verifies the firewall settings and adjusts the ports if necessary. 

Remarks:

    - Disable any webservice with systemctl stop <service name> that use port 80 
    - You need a Debian or Ubuntu server. 
    - The IP of your maschine is connected with your DNS address.
    - For any issue with the email server, check out the remarks of https://github.com/LukeSmithxyz/emailwiz. 
   
 

On the website introDNS.com you may verify your DNS settings of the email server. If everything works, it should look like

![2021-10-24 12_38_58-Window](https://user-images.githubusercontent.com/15387251/138590404-4b6aac4b-30ad-484f-b39a-31ee8b320dcb.png)

