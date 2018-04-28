# kkt - こつこつ、と。
-----
このプログラムは、一定期間（例えば１時間に一回とか。設定可能）に、一定の金額（たとえば１０００円分とか。設定可能）の暗号通貨（btcとかxrpとか。設定可能）を、[ビットバンク](https://bitbank.cc/) で買うためのプログラムです。
現在は作成中のため、まだ買えません。現在のところ、bitbankにアクセスしてbase_coinの残高とtarget_coinのbase_coin建価格を表示するだけです。

# はじめに
無保証です。

# 使い方
bitbankのAPIキーを発行してください。このとき、権限は「参照」と「取引」を許可し、「出金」は許可しないでください。
apikey.yamlというファイルを作成して、bitbankのAPIキーを設定し、kkt.rbを実行してください。

下記にapikey.yamlのサンプルを示します。
~~~yaml
apikey: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
seckey: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
~~~

# おわりに
無保証です。
