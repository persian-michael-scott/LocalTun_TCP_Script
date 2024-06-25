```
bash <(curl -Ls https://raw.githubusercontent.com/persian-michael-scott/LocalTun_TCP_Script/main/Azumi_TUN.sh)
```
# توضیحات
در ابتدا اسکریپت رو روی سرور و سپس کلاینت اجرا کنید.
در حالت Forward منظور از سرور، سرور خارج و کلاینت سرور ایران هست.
در حالت Reverse منظور از سرور، سرور ایران و کلاینت سرور خارج خواهد بود.
در نهایت روی سرور ایران میتونید با استفاده از Haproxy یا هر روش تانل دیگه با آیپی های لوکال که اسکریپت در اختیارتون میذاره تانل رو اجرا کنید.


Haproxy Script by Musixal
```
wget -Nq https://github.com/Musixal/haproxy-tunnel/raw/main/haproxy.sh && bash haproxy.sh
```
