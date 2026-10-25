# プライバシーポリシー（Muscle Mate）

> **このファイルはアプリ内 `frontend/lib/screens/privacy_policy_screen.dart`（文言は
> `frontend/lib/l10n/app_strings.dart` の `privacy.*`）と公開 HTML（`docs/legal/privacy_policy.html`・
> GitHub Pages は `main` ブランチの `/docs` から公開）の唯一のソースです。** どちらを更新する場合も、
> 必ずこの Markdown を先に更新し、両方の表示先に同じ本文を反映してください。

**最終更新日**: 2026年10月25日

---

## 1. はじめに

Muscle Mate（以下「本アプリ」）は、高林 聡（以下「開発者」）が提供する筋力トレーニング支援アプリケーションです。本プライバシーポリシーは、本アプリが扱う情報と、その取り扱いについて説明します。

本アプリは、メニューの作成・分析・記録・読み取りをすべて利用者の端末の中で行います。開発者のサーバーはなく、利用者の記録や個人情報を開発者や第三者へ送信することはありません。

## 2. 扱う情報

本アプリは、次の情報を利用者の端末の中にだけ保存します。

- トレーニング記録（日時、種目、重量、回数、RPE、痛みの有無、メモ）
- 有酸素運動の記録（距離、時間、歩数、平均速度、心拍数の平均・最大などの要約）
- 体力指標（BIG3 の最大重量、トレーニングレベル）
- 任意入力（年齢、体重、目標、使える器具、体の気になるところなど）
- アプリ設定と、購入した PRO のプラン

## 3. 通信（端末の外への送信）

本アプリが端末の外と通信するのは、次の場合だけです。

- 新しいバージョンの案内のため、1 日 1 回まで App Store（Apple）または Google Play（Google）に「公開中のバージョン」を問い合わせます。送るのはアプリの識別子だけです。
- アプリ内課金は、Apple または Google の購入の仕組みで行います。本アプリはカード情報などを受け取りません。PRO を使えるかどうかは、App Store または Google Play の購入の仕組みに「いま有効な購入」があるかを確かめて決めます。
- Android でカメラの文字の読み取りを使うと、Google の ML Kit が性能や利用状況に関する指標を Google へ送ることがあります（§5）。

広告、解析、トラッキングの仕組み（SDK）は使いません。プライバシーポリシーや使い方の動画などのリンクを開くと、ブラウザや YouTube のアプリが開きます。

## 4. 外部 AI への送信

本アプリは、外部の AI サービスへ情報を送信しません。メニューの作成や提案は、端末の中の決まった手順（ルール）で行います。

## 5. カメラと文字の読み取り

マシンの名板やトレッドミルの表示をカメラで読み取る機能で、カメラを使います（利用者が読み取りを始めたときだけ）。文字の読み取りは端末の中で行い、画像と読み取った文字は保存も送信もしません（写真から読むときの一時ファイルは、読んだあとに消します）。

- iPhone：Apple の Vision（端末内）で読み取ります。
- Android：Google の ML Kit（端末内で動く同梱のモデル）で読み取ります。ML Kit は画像を送りませんが、性能や利用状況に関する指標を Google へ送ることがあります。初めて使うときにこのことを説明し、同意を得てからカメラを開きます。

## 6. ヘルスケア・位置情報・身体活動・心拍数（歩く・走る）

「歩く・走る」の機能は、利用者が許可した場合に限り、次の情報を端末の中で使います。いずれも開発者や第三者へ送信せず、広告・解析・販売には使いません。

- 歩数、歩く・走るの運動（時間・距離）：iPhone のヘルスケア（HealthKit）、Android のヘルスコネクトから読み取ります（書き込みはしません）。今日の歩数の表示（「歩く・走る」の画面と庭）と、利用者が選んだ運動の記録への取り込みに使います。
- 位置情報（GPS）：屋外で歩く・走るときの距離の計算に使います。計測を始めてから終えるまでだけ受け取り（画面を消していても計測中は受け取ります。その間、Android では通知を、iPhone では位置情報を使っている表示を出します）、位置の座標は保存しません。「常に許可」のバックグラウンドの位置情報の権限は求めません。
- 身体活動（歩数計）：計測中や「歩く・走る」の画面での歩数を数えるのに使います。
- 心拍数（ヘルスケア・ヘルスコネクト）：心拍の目安（安静時・最大・楽に走る上限）と、走っている間の心拍数の表示・声の案内に使います。心拍数、安静時心拍数、ランのワークアウトの最高心拍数、生年月日（iPhone のみ。年齢の計算に生まれた年だけを使います）を読み取ります。走っている間は新しい心拍数を数秒ごとに読み取り、本アプリで記録した走りの時間帯の心拍数も読み取ります。
- 心拍計・Apple Watch・イヤホン：利用者が選んだ心拍計（Bluetooth の胸ベルトなど）に接続して心拍数を受け取ります（Bluetooth の許可を使います）。Apple Watch に本アプリの Apple Watch 用アプリがある場合は、Apple Watch で測った心拍数を iPhone で受け取ります（Apple Watch と iPhone の間だけのやり取りです）。iPhone では、AirPods Pro 3 などのイヤホンやセンサーの心拍数を受け取るためにワークアウトを動かします。そのためにヘルスケアの「ワークアウト」の書き込みの許可を求めますが、ワークアウトはヘルスケアに保存せず、走り終えたら捨てます。

走っている間の心拍数は、平均・最大などの要約だけを残します。ヘルスケア・ヘルスコネクトから読み取った情報（心拍数の要約・安静時心拍数・生まれた年を含む）は、端末のバックアップの対象から外した保存場所に置きます。

## 7. 端末内データの保存と削除

すべての記録と任意入力は端末の中に保存し、外部のサーバーへのバックアップは行いません。記録の書き出しや、画像の共有・写真への保存は、利用者が操作したときだけ、端末の共有の仕組みを通じて利用者が選んだ先へ渡します。開発者がそのデータを受け取ることはありません。

設定画面の「アカウントデータを削除」から、本アプリが端末の中に保存したデータ（記録・設定、ヘルスケア・ヘルスコネクトから読み取った情報を含む）を削除できます。購入した PRO の状態は、購入を失わないよう残します。

## 8. 医療助言の不提供

本アプリは情報提供を目的としたフィットネス支援であり、医療助言・診断・治療を提供するものではありません。痛みや違和感がある場合は運動を中止し、医療専門家にご相談ください。

持病・術後・妊娠中・若年者は、運動開始前に主治医にご相談ください。

## 9. 児童のプライバシー

本アプリは 13 歳未満のお子様を対象としていません。初回起動時に 13 歳以上であることを確認しますが、この確認では年齢を保存しません（確認したことだけを保存します）。設定で年齢を入力した場合は、端末の中にだけ保存します。

## 10. 許可の取り消し

ヘルスケア・ヘルスコネクト、位置情報、身体活動、Bluetooth、カメラの許可は、端末の設定（ヘルスコネクトはその設定）でいつでも取り消せます。取り消しても、距離や時間は手入力で記録できます。

端末の中のデータは「アカウントデータを削除」からいつでも削除できます。

## 11. ポリシーの変更

本プライバシーポリシーを変更する場合、アプリ内でお知らせします。重要な変更については、再度同意をお願いする場合があります。

## 12. お問い合わせ

プライバシーに関するご質問は、アプリの App Store / Google Play のレビュー欄、または開発者の GitHub ページ（Issue）までお問い合わせください。

---

本アプリを使用することで、本プライバシーポリシーに同意したものとみなします。

---

# Privacy Policy (English)

**Last updated**: October 25, 2026

## 1. Introduction

Muscle Mate (the "App") is a strength-training support application provided by Satoshi Takabayashi (the "Developer"). This Privacy Policy explains what information the App handles and how.

The App creates menus, analyzes, records and recognizes text entirely on your device. The Developer operates no server, and the App never sends your records or personal information to the Developer or any third party.

## 2. Information the App Handles

The App stores the following only on your device:

- Training records (date/time, exercise, weight, reps, RPE, whether you felt pain, notes)
- Cardio records (distance, duration, steps, average speed, and a heart-rate summary such as average and maximum)
- Fitness metrics (BIG3 max weights, training level)
- Optional inputs (age, body weight, goals, available equipment, body areas to be careful with, etc.)
- App settings and the PRO plan you purchased

## 3. Network Communication

The App communicates outside your device only in these cases:

- To let you know about new versions, the App asks the App Store (Apple) or Google Play (Google) for the currently published version at most once a day. Only the app identifier is sent.
- In-app purchases are made through Apple's or Google's purchase system. The App never receives your card details. Whether you can use PRO is decided by checking the App Store or Google Play purchase system for your currently active purchases.
- On Android, when you use text recognition with the camera, Google ML Kit may send performance and usage metrics to Google (see §5).

The App uses no advertising, analytics or tracking SDKs. Opening links such as this policy or how-to videos opens your browser or the YouTube app.

## 4. External AI

The App does not send any information to external AI services. Menus and suggestions are created on your device by fixed rules.

## 5. Camera and Text Recognition

The camera is used to read machine nameplates and treadmill displays, only when you start reading. Text is recognized on your device; images and the recognized text are neither stored nor sent (a temporary file used to read a photo is deleted after reading).

- iPhone: recognized on the device with Apple Vision.
- Android: recognized on the device with Google ML Kit (bundled on-device models). ML Kit does not send images, but may send performance and usage metrics to Google. This is explained, and your consent is asked, before the camera opens for the first time.

## 6. Health Data, Location, Physical Activity and Heart Rate (Walk & Run)

The Walk & Run feature uses the following on your device only when you allow it. None of it is sent to the Developer or any third party, and none of it is used for advertising, analytics or sale.

- Steps and walking/running workouts (duration and distance): read from Apple Health (HealthKit) on iPhone and Health Connect on Android (the App never writes). Used to show today's steps (on the Walk & Run screen and in the garden) and to add workouts you select to your records.
- Location (GPS): used to calculate the distance of an outdoor walk or run. Received only from the start to the end of a session (including while the screen is off during a session; meanwhile Android shows a notification and iPhone shows that location is in use). Coordinates are not stored. The "Always" background location permission is not requested.
- Physical activity (step counter): used to count steps during a session and on the Walk & Run screen.
- Heart rate (Apple Health / Health Connect): used for your heart-rate guide (resting, maximum and the easy-running limit) and to show and announce your heart rate while you run. The App reads heart rate, resting heart rate, the maximum heart rate of running workouts, and date of birth (iPhone only; only the birth year is used, to calculate your age). While you run, it reads new heart-rate values every few seconds, and it also reads heart rate for the times of runs you recorded in the App.
- Heart-rate monitors, Apple Watch and earbuds: the App connects to a heart-rate monitor you choose (such as a Bluetooth chest strap) to receive your heart rate (using the Bluetooth permission). If the App's Apple Watch app is installed, heart rate measured on your Apple Watch is received on your iPhone (exchanged only between your Apple Watch and iPhone). On iPhone, the App runs a workout to receive heart rate from earbuds such as AirPods Pro 3 or other sensors. For this it asks for permission to write workouts to Apple Health, but it never saves the workout to Apple Health and discards it when you finish.

For heart rate during a run, only a summary (such as average and maximum) is kept. Information read from Apple Health or Health Connect (including heart-rate summaries, resting heart rate and birth year) is kept in storage excluded from device backups.

## 7. Storing and Deleting On-Device Data

All records and optional inputs are stored on your device; the App does not back up data to any external server. Exporting records and sharing or saving images happen only when you do so, through your device's share system, to the destination you choose. The Developer never receives that data.

"Delete account data" in Settings deletes the data the App has stored on your device (records, settings, and information read from Apple Health or Health Connect). The state of your PRO purchase is kept so that you do not lose your purchase.

## 8. No Medical Advice

The App is a fitness aid intended for informational purposes and does not provide medical advice, diagnosis or treatment. If you feel pain or discomfort, stop exercising and consult a medical professional.

If you have a chronic condition, are recovering from surgery, are pregnant, or are a minor, consult your doctor before starting to exercise.

## 9. Children's Privacy

The App is not intended for children under 13. At first launch you confirm that you are 13 or older; your age is not stored for this confirmation (only the fact that you confirmed). If you enter your age in Settings, it is stored only on your device.

## 10. Withdrawing Permission

You can withdraw permission for Apple Health / Health Connect, location, physical activity, Bluetooth and the camera at any time in your device settings (Health Connect in its own settings). You can still enter distance and time by hand.

You can delete the data on your device at any time with "Delete account data".

## 11. Changes to This Policy

If we change this Privacy Policy, we will let you know in the App. For significant changes, we may ask for your consent again.

## 12. Contact

For privacy questions, please contact us through the App Store / Google Play review section or the Developer's GitHub page (Issues).

---

By using the App, you are deemed to have agreed to this Privacy Policy.
