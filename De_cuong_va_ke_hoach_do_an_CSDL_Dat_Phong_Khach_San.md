**ĐỀ CƯƠNG VÀ KẾ HOẠCH THỰC HIỆN**

**ĐỒ ÁN CƠ SỞ DỮ LIỆU**

# **XÂY DỰNG HỆ THỐNG QUẢN LÝ ĐẶT PHÒNG KHÁCH SẠN TRỰC TUYẾN**

# **I  THÔNG TIN VÀ ĐỊNH HƯỚNG ĐỀ TÀI**

## **1  Tên đề tài**

Xây dựng hệ thống quản lý đặt phòng khách sạn trực tuyến (mô hình sàn OTA tương tự Booking.com, Airbnb) sử dụng React, Express, Prisma, Redis và PostgreSQL.

## **2  Lý do lựa chọn đề tài**

Hoạt động đặt phòng khách sạn trên nền tảng trung gian phát sinh dữ liệu có tính liên kết cao giữa đối tác lưu trú, danh mục phòng, tồn phòng theo từng đêm, bảng giá động, đơn đặt phòng, thanh toán, hoàn hủy, đánh giá và đối soát hoa hồng sàn. Khi dữ liệu không được mô hình hóa chặt chẽ hoặc xử lý đồng thời thiếu nhất quán, hệ thống dễ gặp các lỗi nghiêm trọng như đặt trùng phòng (overbooking), sai lệch giá tại thời điểm đặt so với lúc đối tác đổi giá, thất thoát công nợ đối tác hoặc truy vấn tìm kiếm chậm khi số lượng phòng và ngày lưu trú tăng lớn.

Đề tài đặt trọng tâm vào thiết kế và khai thác cơ sở dữ liệu quan hệ trên PostgreSQL kết hợp Prisma ORM và bộ nhớ đệm Redis. Ứng dụng web React/Express được xây dựng nhằm kiểm chứng lược đồ, ràng buộc toàn vẹn, giao dịch đồng thời, thủ tục/hàm/trigger và tối ưu hiệu năng truy vấn trên dữ liệu quy mô lớn.

## **3  Mục tiêu nghiên cứu và xây dựng**

Mục tiêu tổng quát: xây dựng hệ thống sàn đặt phòng khách sạn tập trung đa đối tác, bảo đảm toàn vẹn dữ liệu tồn phòng theo ngày, xử lý xuyên suốt quy trình từ tìm kiếm, giữ phòng, thanh toán, nhận/trả phòng đến hỗ trợ khiếu nại và đối soát chi trả đối tác.

Mục tiêu cụ thể: phân tích nghiệp vụ 05 tác nhân; thiết kế ERD (≥ 10 thực thể, đủ 1–1, 1–N, N–N, phân cấp và thực thể yếu) và chuẩn hóa lược đồ đạt tối thiểu 3NF (chứng minh phụ thuộc hàm cho ≥ 03 bảng); triển khai ≥ 12 bảng vật lý trên PostgreSQL qua Prisma Migrate và SQL migration; xây dựng ≥ 20 truy vấn nghiệp vụ, ≥ 03 view (có view phân quyền), ≥ 03 stored procedure, ≥ 02 function, ≥ 02 trigger, ≥ 05 chỉ mục; chứng minh xử lý lỗi đồng thời (đặt trùng phòng/âm tồn); áp dụng ≥ 03 vai trò CSDL, kịch bản sao lưu/phục hồi; tích hợp React + Express + Prisma + Redis với OpenAPI/Swagger, ≥ 15 ca kiểm thử Testcontainers và đóng gói Docker Compose.

## **4  Đối tượng và phạm vi**

Đối tượng quản lý gồm tài khoản người dùng, hồ sơ đối tác khách sạn, phân cấp địa điểm, tiện ích, khách sạn, loại phòng, phòng vật lý, tồn phòng và giá theo ngày (`room_inventory`), chính sách hủy, mã khuyến mãi, đơn đặt phòng và chi tiết hạng mục đặt, giao dịch thanh toán/hoàn tiền, đánh giá, phiếu hỗ trợ khách hàng, kỳ đối soát hoa hồng/chi trả đối tác và nhật ký kiểm toán. Hệ thống có 05 tác nhân tương tác trực tiếp: Quản trị viên hệ thống, Chủ khách sạn / Đối tác, Khách hàng, Nhân viên Hỗ trợ Khách hàng và Kế toán Sàn.

Phạm vi bắt buộc: hỗ trợ đa khách sạn thuộc nhiều đối tác và nhiều địa điểm phân cấp; tìm kiếm phòng trống theo khoảng ngày và lọc tiện ích; giữ phòng tạm thời có thời hạn, đặt phòng, thanh toán mô phỏng, hủy theo chính sách; check-in/check-out và đánh giá sau khi hoàn thành lưu trú; tiếp nhận/xử lý ticket khiếu nại; đối soát hoa hồng sàn và lập phiếu chi trả đối tác. Dữ liệu thanh toán sử dụng phương thức mô phỏng nội bộ.

Ngoài phạm vi bắt buộc: kết nối cổng thanh toán thực tế (VNPay, MoMo, Stripe), xuất hóa đơn điện tử cơ quan thuế, đồng bộ kênh OTA ngoài (Channel Manager/iCal), khóa cửa thông minh và kiểm tra KYC tự động qua bên thứ ba. Các nghiệp vụ như định giá tự động bằng AI hoặc trò chuyện thời gian thực (WebSocket) được xếp vào hướng phát triển mở rộng.

## **5  Phương pháp thực hiện**

Khảo sát quy trình sàn đặt phòng OTA; đặc tả tác nhân, use case và quy tắc nghiệp vụ; thiết kế mô hình khái niệm và chuẩn hóa lược đồ quan hệ; cài đặt migration, thủ tục, trigger và dữ liệu giả lập tiếng Việt quy mô ≥ 10.000 và ≥ 100.000 bản ghi; kiểm thử tự động bằng Testcontainers và kiểm thử đồng thời bằng k6/JMeter/2 phiên SQL song song; đo `EXPLAIN ANALYZE` trước và sau chỉ mục. Kế hoạch thực hiện xây dựng cho nhóm **05 thành viên** trong **08 tuần**.

# **II  YÊU CẦU HỆ THỐNG**

## **1  Vai trò và phạm vi truy cập**

| Vai trò | Phạm vi | Quyền chính |
| :---- | :---- | :---- |
| A01 Quản trị viên hệ thống | Toàn hệ thống | Duyệt/tạm khóa hồ sơ đối tác và khách sạn; quản lý danh mục địa điểm, tiện ích, khuyến mãi sàn; phân quyền tài khoản nội bộ; cấu hình tỷ lệ hoa hồng mặc định; xem nhật ký hệ thống. |
| A02 Chủ khách sạn / Đối tác | Các khách sạn thuộc sở hữu | Đăng ký hồ sơ đối tác; tạo/cập nhật khách sạn, loại phòng, phòng, tiện ích, chính sách hủy; cài đặt giá và mở/đóng quỹ phòng theo ngày; xác nhận check-in/check-out; xem doanh thu và phiếu đối soát của mình. |
| A03 Khách hàng | Dữ liệu cá nhân và đơn của mình | Tìm kiếm khách sạn/phòng trống; đặt giữ phòng và thanh toán mô phỏng; xem/hủy đơn đặt phòng của mình; gửi đánh giá cho đơn đã hoàn thành; tạo và trao đổi trên phiếu hỗ trợ. |
| A04 Nhân viên Hỗ trợ Khách hàng | Đơn đặt phòng, đánh giá và ticket được phân công | Tiếp nhận/xử lý ticket khiếu nại của khách hàng và đối tác; tra cứu thông tin đơn liên quan; thực hiện hủy ngoại lệ/hoàn tiền theo quy trình tranh chấp; ẩn đánh giá vi phạm quy chuẩn. |
| A05 Kế toán Sàn | Dữ liệu thanh toán và đối soát toàn sàn | Chốt kỳ đối soát định kỳ; tổng hợp doanh thu, hoa hồng và tiền hoàn; lập và xác nhận thanh toán phiếu chi trả (payout) cho đối tác; xuất báo cáo tài chính sàn. |

Cả 05 tác nhân đều tương tác trực tiếp với ứng dụng React theo giao diện và phân quyền riêng. Backend Express kiểm tra xác thực JWT, vai trò và quyền sở hữu dữ liệu (ví dụ đối tác chỉ thao tác khách sạn do mình sở hữu; khách hàng chỉ xem/hủy đơn của chính mình) ở tầng API, không phụ thuộc vào việc ẩn nút ở frontend.

## **2  Danh mục chức năng bắt buộc**

| Mã | Phân hệ | Yêu cầu chức năng |
| :---- | :---- | :---- |
| F01 | Tài khoản và phân quyền | Đăng ký/đăng nhập 05 tác nhân; băm mật khẩu bcrypt/Argon2; kiểm soát quyền theo vai trò và chủ sở hữu dữ liệu. |
| F02 | Danh mục và duyệt đối tác | Quản lý cây địa điểm phân cấp, tiện ích, mã khuyến mãi; đăng ký và phê duyệt đối tác/khách sạn. |
| F03 | Quản lý phòng và tồn theo ngày | Quản lý loại phòng, phòng vật lý, chính sách hủy; sinh/cập nhật quỹ phòng và giá theo từng ngày (`room_inventory`). |
| F04 | Tìm kiếm và giữ/đặt phòng | Tìm kiếm theo địa điểm, khoảng ngày, số khách, tiện ích (kết hợp cache Redis); giữ chỗ, đặt phòng và chốt giá từng đêm. |
| F05 | Thanh toán và vận hành lưu trú | Thanh toán mô phỏng (chống lặp bằng `idempotency_key`); check-in, gán phòng vật lý, check-out, hủy đơn và hoàn tiền theo chính sách. |
| F06 | Đánh giá và hỗ trợ khách hàng | Khách hàng viết đánh giá sau trả phòng; nhân viên hỗ trợ xử lý ticket tranh chấp, hủy ngoại lệ và kiểm duyệt đánh giá. |
| F07 | Đối soát hoa hồng và chi trả | Chốt kỳ đối soát, tính hoa hồng sàn, tạo phiếu payout cho từng đối tác và đánh dấu chi trả. |
| F08 | Thống kê và kiểm toán | Báo cáo công suất phòng, doanh thu đối tác/toàn sàn, tỷ lệ hủy, top khách sạn và truy vết nhật ký `audit_logs`. |

## **3  Danh mục use case**

- Các tác nhân:
  * A01: Quản trị viên hệ thống
  * A02: Chủ khách sạn / Đối tác
  * A03: Khách hàng
  * A04: Nhân viên Hỗ trợ Khách hàng
  * A05: Kế toán Sàn

| Mã và tên use case | Tác nhân chính | Điều kiện và kết quả chính |
| :---- | :---- | :---- |
| UC01 Đăng ký và đăng nhập | A01–A05 | Xác thực email/mật khẩu băm; cấp phiên đăng nhập theo đúng vai trò. |
| UC02 Phân quyền nhân sự nội bộ | A01 | Tạo hoặc cập nhật vai trò A04/A05, khóa/mở khóa tài khoản vi phạm. |
| UC03 Quản lý địa điểm và tiện ích | A01 | Tạo/sửa cây địa điểm phân cấp và danh mục tiện ích chuẩn toàn sàn. |
| UC04 Phê duyệt đối tác và khách sạn | A01 | Kiểm tra hồ sơ KYC đối tác và duyệt/từ chối khách sạn được phép hiển thị. |
| UC05 Quản lý khuyến mãi toàn sàn | A01 | Tạo và giới hạn lượt sử dụng mã giảm giá theo thời gian hiệu lực. |
| UC06 Đăng ký hồ sơ đối tác và khách sạn | A02 | Khai báo thông tin kinh doanh, ngân hàng, khách sạn và gắn tiện ích. |
| UC07 Quản lý loại phòng và phòng vật lý | A02 | Thiết lập hạng phòng, sức chứa, giá gốc, danh sách số phòng và chính sách hủy. |
| UC08 Cập nhật giá và quỹ phòng theo ngày | A02 | Mở/đóng bán, chỉnh giá theo ngày lễ/cuối tuần và cập nhật `total_allotment`. |
| UC09 Tìm kiếm khách sạn và phòng trống | A03 | Lọc theo địa điểm (gồm khu vực con), khoảng ngày, số khách, tiện ích còn đủ phòng. |
| UC10 Tạo đơn giữ phòng (Hold Booking) | A03 | Khóa tồn phòng mọi đêm trong khoảng đặt, giữ chỗ 15 phút, chốt snapshot giá. |
| UC11 Thanh toán đơn đặt phòng | A03 | Xác nhận thanh toán mô phỏng với `idempotency_key`; chuyển giữ chỗ sang đã đặt (`CONFIRMED`). |
| UC12 Hủy đơn đặt phòng theo chính sách | A03 | Kiểm tra thời hạn trước check-in; giải phóng tồn phòng và tính hoàn tiền nếu đủ điều kiện. |
| UC13 Check-in và Check-out khách lưu trú | A02 | Gán phòng vật lý khi nhận phòng; hoàn tất đơn (`COMPLETED`) khi khách trả phòng. |
| UC14 Viết đánh giá sau lưu trú | A03 | Chỉ áp dụng cho đơn `COMPLETED` của chính khách hàng; cập nhật điểm trung bình khách sạn. |
| UC15 Tạo và trao đổi phiếu hỗ trợ | A02, A03 | Khách hàng hoặc đối tác gửi ticket khiếu nại liên quan đến đơn đặt phòng hoặc sự cố. |
| UC16 Tiếp nhận và xử lý ticket tranh chấp | A04 | Tra cứu đơn/lịch sử giao dịch, phản hồi các bên, xử lý hủy ngoại lệ và đóng ticket. |
| UC17 Kiểm duyệt đánh giá vi phạm | A04 | Ẩn đánh giá spam/xúc phạm kèm lý do và cập nhật lại điểm đánh giá khách sạn. |
| UC18 Xem doanh thu và phiếu đối soát cơ sở | A02 | Đối tác xem công suất, doanh thu theo ngày/tháng và chi tiết payout của mình. |
| UC19 Chốt kỳ đối soát hoa hồng sàn | A05 | Tổng hợp booking `COMPLETED` chưa chi trả trong kỳ, tính hoa hồng và sinh payout. |
| UC20 Xác nhận chi trả đối tác (Payout) | A05 | Đối soát số tiền thực nhận sau hoàn hủy và xác nhận đã chuyển khoản cho đối tác. |
| UC21 Xem báo cáo tài chính toàn sàn | A01, A05 | Báo cáo doanh thu gộp (GMV), hoa hồng sàn, tiền hoàn và công nợ chưa chi trả. |
| UC22 Tra cứu nhật ký kiểm toán hệ thống | A01 | Xem lịch sử thay đổi dữ liệu nhạy cảm (duyệt đối tác, sửa giá, hủy ngoại lệ, payout). |

## **4  Yêu cầu phi chức năng**

* Toàn vẹn và đồng thời: không đặt trùng vượt quá số phòng mở bán (`booked_count + held_count <= total_allotment`); không trừ tồn phòng hai lần; không thanh toán lặp hoặc đối soát chi trả trùng một booking.
* Hiệu năng: tận dụng Redis cache cho truy vấn tìm kiếm phổ biến và cây địa điểm; tối ưu chỉ mục PostgreSQL để truy vấn tìm kiếm phòng trống và thống kê đạt thời gian phản hồi ổn định trên tập ≥ 100.000 bản ghi.
* Bảo mật và phân quyền: mật khẩu băm bằng bcrypt/Argon2; truy vấn SQL tham số hóa; phân tách vai trò CSDL (`db_migrator`, `app_rw`, `reporting_ro`); bí mật lưu trong biến môi trường `.env`.
* Khả năng bảo trì và triển khai: tách lớp rõ ràng giữa React, Express (routes/controllers/services/repositories) và tầng CSDL (Prisma schema, migrations, thủ tục, view, trigger); dựng toàn bộ môi trường qua `docker compose up`.

# **III  QUY TRÌNH VÀ QUY TẮC NGHIỆP VỤ**

## **1  Quy trình tìm kiếm, giữ phòng và đặt phòng**

Khách hàng nhập khu vực điểm đến, ngày nhận phòng (`check_in_date`), ngày trả phòng (`check_out_date`), số khách và các tiện ích mong muốn. Hệ thống tra cứu cây địa điểm con (hoặc lấy từ Redis nếu hợp lệ), kiểm tra các loại phòng thuộc khách sạn đã duyệt có tổng số phòng trống khả dụng (`total_allotment - booked_count - held_count >= số phòng yêu cầu`) cho **mọi đêm** từ `check_in_date` đến `check_out_date - 1` và trạng thái mở bán (`is_closed = FALSE`).

Khi khách hàng chọn đặt phòng, hệ thống gọi thủ tục giao dịch khóa các dòng `room_inventory` liên quan theo thứ tự tăng dần `(room_type_id, stay_date)` để tránh deadlock. Hệ thống tăng `held_count`, tạo đơn `bookings` ở trạng thái `HOLD` (hết hạn sau 15 phút), ghi chi tiết `booking_items` và chụp đơn giá từng đêm vào `booking_night_rates`. Dù đối tác có sửa `nightly_price` sau đó, đơn đã tạo vẫn giữ nguyên đơn giá đã chốt. Hết thời gian giữ chỗ mà chưa thanh toán, tác vụ dọn dẹp hoặc thủ tục sẽ giải phóng `held_count` và chuyển đơn sang `CANCELLED`.

## **2  Quy trình thanh toán, nhận/trả phòng và hủy đơn**

Khách hàng thực hiện thanh toán mô phỏng với `idempotency_key` duy nhất. Trong cùng một giao dịch PostgreSQL, hệ thống kiểm tra đơn còn ở trạng thái `HOLD`/`PENDING_PAYMENT` và chưa quá hạn, tạo bản ghi `payments` trạng thái `SUCCESS`, chuyển số lượng từ `held_count` sang `booked_count` trên `room_inventory` và đổi trạng thái đơn sang `CONFIRMED`.

Khi khách đến nhận phòng, đối tác thực hiện check-in và gán `assigned_room_id` là phòng vật lý đang ở trạng thái `AVAILABLE` thuộc đúng `room_type_id` của đơn; trạng thái đơn chuyển sang `CHECKED_IN`. Khi khách trả phòng, đối tác xác nhận `COMPLETED`. Lúc này khách hàng mới được phép gửi tối đa 01 đánh giá (`reviews`) cho đơn đó.

Khi khách hàng hủy đơn trước check-in, hệ thống đối chiếu `cancellation_policies` gắn với đơn tại thời điểm đặt: nếu thời gian hủy sớm hơn mốc `free_cancel_hours` thì hoàn 100% số tiền đã trả; ngược lại áp dụng mức phạt `penalty_percent` và tạo bản ghi `payments` loại `REFUND` tương ứng, đồng thời giảm `booked_count` hoặc `held_count` trên `room_inventory`. Trường hợp tranh chấp ngoại lệ do Nhân viên Hỗ trợ Khách hàng xử lý qua ticket được ghi nhận lý do vào `audit_logs`.

## **3  Quy trình hỗ trợ khiếu nại và đối soát tài chính sàn**

Khách hàng hoặc đối tác tạo `support_tickets` gắn với `booking_id` (nếu có). Nhân viên Hỗ trợ Khách hàng (A04) tiếp nhận ticket, trao đổi qua `ticket_messages` (có cờ ghi chú nội bộ `is_internal_note` ẩn với khách/đối tác) và xử lý nghiệp vụ theo thẩm quyền.

Cuối kỳ đối soát, Kế toán Sàn (A05) chạy quy trình tổng hợp các đơn ở trạng thái `COMPLETED` chưa từng xuất hiện trong `payout_items`. Hệ thống nhóm theo `partner_id`, tính tổng tiền phòng thực thu sau giảm giá sàn/hoàn tiền, nhân tỷ lệ hoa hồng (`commission_rate`) đã chốt trên đơn để ra số tiền thực nhận (`net_payout = gross_amount - commission_total`), tạo `settlement_batches`, `partner_payouts` và `payout_items` trong một giao dịch nguyên tử. Ràng buộc `UNIQUE(booking_id)` trên `payout_items` bảo đảm một đơn đặt phòng không bao giờ bị chi trả hai lần.

## **4  Nguyên tắc tính tiền, hoa hồng và ví dụ đối chứng**

Tiền phòng của một đơn là tổng `(nightly_price_snapshot × quantity)` qua từng đêm lưu trú trong khoảng `[check_in_date, check_out_date)`. Tiền lưu ở kiểu `NUMERIC(18,0)` (đơn vị đồng VND). Nếu áp dụng mã khuyến mãi sàn hợp lệ, `total_amount = room_subtotal - discount_amount` (không âm). Hoa hồng sàn tính trên giá trị phòng trước mã giảm giá của sàn (hoặc theo cấu hình cố định của khách sạn tại thời điểm đặt): `commission_amount = ROUND(room_subtotal × commission_rate / 100, 0)`.

Ví dụ đối chứng: Khách hàng đặt 02 phòng Deluxe trong 02 đêm tại khách sạn có `commission_rate = 15%`. Đêm thứ nhất giá 1.000.000 đồng/phòng, đêm thứ hai (cuối tuần) giá 1.200.000 đồng/phòng. Tổng tiền phòng `room_subtotal = (1.000.000 + 1.200.000) × 2 = 4.400.000` đồng. Khách dùng mã giảm giá sàn 200.000 đồng → khách thanh toán `total_amount = 4.200.000` đồng. Sau khi khách hoàn thành lưu trú (`COMPLETED`), hoa hồng sàn `commission_amount = 4.400.000 × 15% = 660.000` đồng; số tiền đối tác được đối soát chi trả là `4.400.000 - 660.000 = 3.740.000` đồng (phần giảm giá 200.000 đồng do sàn tài trợ). Nếu khách hủy trong thời hạn miễn phí hủy (`free_cancel_hours = 48h`), hệ thống hoàn 4.200.000 đồng cho khách và hoàn trả 02 phòng cho cả 02 đêm vào `room_inventory`.

## **5  Danh mục quy tắc nghiệp vụ**

| Mã | Quy tắc có thể kiểm chứng | Use case liên quan |
| :---- | :---- | :---- |
| BR01 | Quản trị viên truy cập toàn hệ thống; đối tác chỉ quản lý khách sạn và payout của mình; khách hàng chỉ thao tác đơn và đánh giá của mình; hỗ trợ/kế toán truy cập đúng phân hệ được cấp. | UC01–UC22 |
| BR02 | Email người dùng, mã số thuế đối tác, mã khách sạn, mã đặt phòng, mã khuyến mãi và mã kỳ đối soát là duy nhất toàn hệ thống. | UC01, UC05, UC06, UC10, UC19 |
| BR03 | Chỉ khách sạn có `approval_status = 'APPROVED'` và `is_active = TRUE` mới hiển thị tìm kiếm và cho phép tạo đơn đặt phòng. | UC04, UC09, UC10 |
| BR04 | Ngày trả phòng phải lớn hơn ngày nhận phòng (`check_out_date > check_in_date`); ngày trong quá khứ không được đặt mới. | UC09, UC10 |
| BR05 | Tại mọi ngày lưu trú, tổng phòng đã đặt và đang giữ chỗ không được vượt quá quỹ phòng mở bán (`booked_count + held_count <= total_allotment`) và ngày đó không bị đóng (`is_closed = FALSE`). | UC08, UC10, UC11 |
| BR06 | Đơn đặt phòng chỉ chứa các loại phòng thuộc cùng một khách sạn; `quantity` và `nights` phải lớn hơn 0. | UC10 |
| BR07 | Giá phòng từng đêm được chụp vào `booking_night_rates` khi tạo đơn; đối tác chỉnh giá sau đó không ảnh hưởng các đơn đã tạo. | UC08, UC10, UC11 |
| BR08 | Giữ phòng (`HOLD`) chỉ có hiệu lực trong khoảng thời gian quy định (`hold_expires_at`); quá hạn chưa thanh toán sẽ bị giải phóng tồn kho. | UC10, UC11 |
| BR09 | Yêu cầu thanh toán gửi lại cùng `idempotency_key` chỉ được xử lý thành công tối đa một lần; tổng tiền thanh toán thành công phải khớp `bookings.total_amount`. | UC11 |
| BR10 | Check-in chỉ thực hiện trên đơn `CONFIRMED`; phòng vật lý gán cho khách phải ở trạng thái `AVAILABLE` và thuộc đúng `room_type_id` của dòng đặt. | UC13 |
| BR11 | Hủy đơn trước hạn miễn phí hủy được hoàn 100% số tiền đã thu; hủy trễ hạn áp dụng đúng `penalty_percent` của chính sách đã chốt trên đơn; không hủy đơn đã `COMPLETED`. | UC12, UC16 |
| BR12 | Khi hủy đơn hợp lệ, hệ thống phải hoàn trả đúng số lượng phòng đang giữ/đã đặt về `room_inventory` cho từng đêm tương ứng trong cùng giao dịch. | UC12, UC16 |
| BR13 | Mỗi đơn `COMPLETED` chỉ được viết tối đa 01 đánh giá bởi chính khách hàng đặt đơn; điểm đánh giá từ 1 đến 5 sao. | UC14 |
| BR14 | Các cột tổng hợp `hotels.avg_rating` và `hotels.review_count` chỉ tính từ các đánh giá có `moderation_status = 'VISIBLE'` và được đồng bộ nhất quán qua trigger. | UC14, UC17 |
| BR15 | Phiếu hỗ trợ nếu gắn `booking_id` phải thuộc khách hàng hoặc đối tác liên quan đến đơn đó; ghi chú nội bộ (`is_internal_note = TRUE`) không hiển thị cho khách hàng/đối tác. | UC15, UC16 |
| BR16 | Chỉ đơn trạng thái `COMPLETED` mới đủ điều kiện đưa vào kỳ đối soát; mỗi đơn chỉ xuất hiện tối đa một lần trong `payout_items`. | UC19, UC20 |
| BR17 | Hoa hồng và tỷ lệ phạt phải nằm trong khoảng `[0, 100]`; tổng thanh toán và số tiền chi trả đối tác không được âm. | UC04, UC07, UC19, UC20 |
| BR18 | Chứng từ thanh toán thành công, phiếu payout đã thanh toán và nhật ký `audit_logs` không được phép xóa vật lý hoặc sửa trực tiếp bỏ qua nghiệp vụ. | UC11, UC20, UC22 |

# **IV  THIẾT KẾ CƠ SỞ DỮ LIỆU DỰ KIẾN**

## **1  Định hướng mô hình hóa**

Quy ước: PK là khóa chính; FK là khóa ngoại. Khóa chính đơn dùng `BIGINT GENERATED ALWAYS AS IDENTITY` (ánh xạ `BigInt @id @default(autoincrement())` trong Prisma). Thực thể yếu và bảng liên kết N–N dùng khóa chính ghép. Toàn bộ số tiền dùng `NUMERIC(18,0)`, tỷ lệ phần trăm dùng `NUMERIC(5,2)`, không dùng kiểu số thực dấu phẩy động (`FLOAT`/`DOUBLE`) cho tiền tệ.

Mô hình dự kiến gồm **22 bảng** (vượt ngưỡng ≥ 12 bảng), bảo đảm:
- Quan hệ **1–1**: `users` – `partner_profiles`; `bookings` – `reviews`.
- Quan hệ **1–N**: `hotels` – `room_types`, `bookings` – `payments`, `settlement_batches` – `partner_payouts`,...
- Quan hệ **N–N**: `hotels` – `amenities` qua bảng `hotel_amenities`.
- Quan hệ **phân cấp (tự tham chiếu)**: `locations.parent_id` → `locations.id` (Quốc gia → Tỉnh/Thành → Quận/Huyện → Khu vực).
- **Thực thể yếu**: `booking_items` (khóa ghép `(booking_id, line_no)` phụ thuộc `bookings`) và `ticket_messages` (khóa ghép `(ticket_id, seq_no)` phụ thuộc `support_tickets`).

## **2  Nhóm người dùng, đối tác và danh mục nền**

| Bảng | Khóa và thuộc tính tiêu biểu | Mục đích |
| :---- | :---- | :---- |
| users | id PK; email UNIQUE; password\_hash; full\_name; phone; role; is\_active; created\_at | Tài khoản chung 05 vai trò: ADMIN, PARTNER, CUSTOMER, SUPPORT, ACCOUNTANT. |
| partner\_profiles | user\_id PK/FK -> users; business\_name; tax\_code UNIQUE; bank\_account; bank\_name; kyc\_status; verified\_by FK NULL; verified\_at | Hồ sơ kinh doanh/ngân hàng của đối tác (quan hệ 1–1 với users). |
| locations | id PK; parent\_id FK NULL -> locations; code UNIQUE; name; level | Cây phân cấp địa điểm phục vụ tìm kiếm khu vực và CTE đệ quy. |
| amenities | id PK; code UNIQUE; name; category | Danh mục tiện ích dùng chung (Wifi, Hồ bơi, Bãi đỗ xe, Bữa sáng...). |
| promotions | id PK; code UNIQUE; discount\_type; discount\_value; min\_order\_amount; valid\_from; valid\_to; usage\_limit; used\_count | Mã giảm giá toàn sàn kèm ngưỡng đơn tối thiểu và giới hạn lượt. |

## **3  Nhóm khách sạn, phòng và quỹ phòng theo ngày**

| Bảng | Khóa và thuộc tính tiêu biểu | Mục đích |
| :---- | :---- | :---- |
| hotels | id PK; partner\_id FK; location\_id FK; code UNIQUE; name; address; star\_rating; approval\_status; commission\_rate; avg\_rating; review\_count; is\_active | Thông tin khách sạn; có 02 cột phi chuẩn hóa có kiểm soát (`avg_rating`, `review_count`). |
| hotel\_amenities | hotel\_id FK; amenity\_id FK; PK(hotel\_id, amenity\_id) | Bảng trung gian N–N gắn tiện ích cho từng khách sạn. |
| cancellation\_policies | id PK; hotel\_id FK; name; free\_cancel\_hours; penalty\_percent; is\_default | Chính sách hủy phòng theo từng khách sạn. |
| room\_types | id PK; hotel\_id FK; code; name; max\_adults; max\_children; base\_price; total\_rooms; is\_active; UNIQUE(hotel\_id, code) | Hạng phòng (Standard, Deluxe, Suite...) thuộc khách sạn. |
| rooms | id PK; room\_type\_id FK; room\_number; floor; status; UNIQUE(room\_type\_id, room\_number) | Phòng vật lý cụ thể để gán khi check-in và theo dõi bảo trì. |
| room\_inventory | room\_type\_id FK; stay\_date; PK(room\_type\_id, stay\_date); total\_allotment; booked\_count; held\_count; nightly\_price; is\_closed | Quỹ phòng và giá theo từng ngày; bảng quy mô ≥ 100.000 bản ghi để đo hiệu năng. |

## **4  Nhóm đặt phòng, thanh toán, hỗ trợ, đối soát và kiểm toán**

| Bảng | Khóa và thuộc tính tiêu biểu | Mục đích |
| :---- | :---- | :---- |
| bookings | id PK; booking\_code UNIQUE; customer\_id FK; hotel\_id FK; promotion\_id FK NULL; policy\_id FK; check\_in\_date; check\_out\_date; guest\_count; status; room\_subtotal; discount\_amount; total\_amount; commission\_amount; hold\_expires\_at; created\_at | Bảng giao dịch đặt phòng chính (≥ 10.000 bản ghi nghiệp vụ). |
| booking\_items | booking\_id FK; line\_no; PK(booking\_id, line\_no); room\_type\_id FK; assigned\_room\_id FK NULL; quantity; nights; unit\_price\_avg; line\_total | Thực thể yếu chi tiết loại phòng và phòng vật lý được gán trong đơn. |
| booking\_night\_rates | id PK; booking\_id FK; room\_type\_id FK; stay\_date; quantity; nightly\_price\_snapshot; UNIQUE(booking\_id, room\_type\_id, stay\_date) | Snapshot đơn giá từng đêm bất biến tại thời điểm đặt. |
| payments | id PK; booking\_id FK; payment\_type; method; amount; status; idempotency\_key UNIQUE; paid\_at | Giao dịch thu tiền (`CHARGE`) và hoàn tiền (`REFUND`) chống lặp. |
| reviews | id PK; booking\_id FK UNIQUE; customer\_id FK; hotel\_id FK; rating; comment; moderation\_status; created\_at | Đánh giá sau lưu trú (1–1 với booking đã hoàn thành). |
| support\_tickets | id PK; ticket\_code UNIQUE; booking\_id FK NULL; customer\_id FK; assigned\_staff\_id FK NULL; category; priority; status; subject; created\_at; resolved\_at | Phiếu yêu cầu hỗ trợ/khiếu nại do Nhân viên Hỗ trợ (A04) xử lý. |
| ticket\_messages | ticket\_id FK; seq\_no; PK(ticket\_id, seq\_no); sender\_id FK; message\_body; is\_internal\_note; created\_at | Thực thể yếu lưu chuỗi tin nhắn trao đổi và ghi chú nội bộ trên ticket. |
| settlement\_batches | id PK; batch\_code UNIQUE; period\_start; period\_end; created\_by FK; status; created\_at | Đợt đối soát định kỳ do Kế toán Sàn (A05) tạo. |
| partner\_payouts | id PK; batch\_id FK; partner\_id FK; gross\_amount; commission\_total; net\_payout; status; paid\_at; UNIQUE(batch\_id, partner\_id) | Tổng hợp tiền phải trả cho từng đối tác trong một đợt đối soát. |
| payout\_items | payout\_id FK; booking\_id FK UNIQUE; PK(payout\_id, booking\_id); booking\_amount; commission\_amount; net\_amount | Chi tiết từng booking đã đối soát; `booking_id UNIQUE` chống chi trả trùng. |
| audit\_logs | id PK; actor\_id FK NULL; action; entity\_type; entity\_id; old\_data JSONB NULL; new\_data JSONB NULL; created\_at | Nhật ký kiểm toán ghi nhận thay đổi dữ liệu trọng yếu qua trigger/dịch vụ. |

# **V  RÀNG BUỘC VÀ XỬ LÝ GIAO DỊCH**

## **1  Ràng buộc toàn vẹn**

| Mã | Quy tắc | Cơ chế triển khai dự kiến |
| :---- | :---- | :---- |
| R01 | Ngày trả phòng sau ngày nhận phòng; giá trị tiền, số lượng, `star_rating`, `rating` hợp lệ. | `CHECK (check_out_date > check_in_date)`, `CHECK (rating BETWEEN 1 AND 5)`, `CHECK (total_amount >= 0)`. |
| R02 | Không âm hoặc vượt quỹ phòng mở bán theo từng ngày. | `CHECK (booked_count >= 0 AND held_count >= 0 AND booked_count + held_count <= total_allotment)`. |
| R03 | Tỷ lệ hoa hồng, tỷ lệ phạt hủy và phần trăm giảm giá hợp lệ. | `CHECK (commission_rate BETWEEN 0 AND 100)`, `CHECK (penalty_percent BETWEEN 0 AND 100)`. |
| R04 | Không trùng mã phòng trong một loại phòng, mã loại phòng trong một khách sạn, số thứ tự dòng trong đơn/ticket. | `UNIQUE(room_type_id, room_number)`, `UNIQUE(hotel_id, code)`, `PK(booking_id, line_no)`, `PK(ticket_id, seq_no)`. |
| R05 | Mỗi booking tối đa 01 đánh giá và tối đa 01 lần vào phiếu chi trả payout. | `UNIQUE(booking_id)` trên `reviews` và `payout_items`. |
| R06 | Chống thanh toán lặp khi mạng retry; gán phòng vật lý không trùng đang sử dụng. | `UNIQUE(idempotency_key)` trên `payments`; khóa dòng khi check-in và kiểm tra trạng thái phòng. |
| R07 | Chính sách xóa/cập nhật khóa ngoại nhất quán bảo vệ lịch sử tài chính. | `ON DELETE RESTRICT` cho `bookings`, `payments`, `payout_items`, `room_types`; `ON DELETE CASCADE` chỉ áp dụng cho `hotel_amenities`, `booking_items`, `ticket_messages` khi ở trạng thái nháp/thuộc cha xóa được; `ON UPDATE CASCADE` cho mã tham chiếu phù hợp. |
| R08 | Chỉ đánh giá đơn đã `COMPLETED` và đồng bộ `avg_rating`/`review_count`. | Trigger `BEFORE INSERT/UPDATE` và `AFTER INSERT/UPDATE/DELETE` trên `reviews`. |

## **2  Các giao dịch trọng yếu và xử lý đồng thời**

- **Tái hiện và khắc phục lỗi đồng thời**:
  - Tình huống lỗi thực tế: Hai khách hàng gửi yêu cầu đặt phòng cuối cùng (`total_allotment = 5`, `booked_count = 4`, `held_count = 0`) cùng một thời điểm. Nếu đọc rồi mới cập nhật không có khóa (mức cô lập `READ COMMITTED` mặc định), cả hai phiên cùng đọc thấy còn 1 phòng và cùng ghi nhận thành công (**lost update / overbooking**).
  - Biện pháp khắc phục: Bọc quy trình giữ phòng trong giao dịch PostgreSQL, sử dụng `SELECT ... FROM room_inventory WHERE room_type_id = $1 AND stay_date >= $2 AND stay_date < $3 ORDER BY stay_date ASC FOR UPDATE` (khóa dòng theo thứ tự ngày và `room_type_id` tăng dần để tránh deadlock), kết hợp ràng buộc `CHECK (booked_count + held_count <= total_allotment)`. Nếu dùng Prisma, thực thi qua `prisma.$transaction` gọi thủ tục hoặc câu lệnh khóa tường minh, kèm retry giới hạn khi gặp deadlock/serialization failure.
  - Vai trò của Redis: Cache dữ liệu tìm kiếm/địa điểm và cung cấp cơ chế rate-limit/lock mềm theo khóa `lock:room:{room_type_id}` ở tầng Express để giảm tải tranh chấp sớm; tuy nhiên mọi quyết định trừ quỹ phòng bắt buộc kiểm chứng tại PostgreSQL nhằm bảo đảm ACID tuyệt đối kể cả khi Redis khởi động lại.
- **Giao dịch thanh toán và đối soát**: Thanh toán kiểm tra `idempotency_key` trong transaction trước khi chuyển `held_count` → `booked_count` và ghi `payments`. Hủy đơn tính hoàn tiền, ghi `REFUND` và trả tồn phòng trong một transaction. Chốt kỳ đối soát khóa các `bookings` đủ điều kiện và chèn đồng thời vào `partner_payouts` và `payout_items`.

## **3  Thủ tục, hàm, view, trigger và chỉ mục**

- **Stored Procedure (≥ 03)**:
  1. `sp_create_booking_hold(...)`: khóa `room_inventory`, kiểm tra phòng đóng/đủ chỗ mọi đêm, tăng `held_count`, chèn `bookings`, `booking_items`, `booking_night_rates`; bắt `EXCEPTION` và `RAISE` mã lỗi nghiệp vụ.
  2. `sp_confirm_booking_payment(...)`: xác nhận thanh toán với `idempotency_key`, chuyển `held_count` → `booked_count`, cập nhật `bookings.status = 'CONFIRMED'`.
  3. `sp_cancel_booking(...)`: tính phí phạt, giải phóng `held_count`/`booked_count`, tạo bản ghi `REFUND` nếu hợp lệ.
  4. `sp_generate_settlement_batch(...)`: tổng hợp đơn `COMPLETED` chưa đối soát, tính hoa hồng và sinh `partner_payouts` + `payout_items`.
- **Function (≥ 02)**:
  1. `fn_calculate_booking_quote(p_room_type_id, p_check_in, p_check_out, p_qty, p_promo_code)`: tính tổng tiền gốc, mức giảm giá và số tiền thanh toán dự kiến.
  2. `fn_calculate_refund_amount(p_booking_id, p_cancel_time)`: trả về số tiền hoàn dựa theo chính sách hủy gắn trên đơn.
- **View (≥ 03, có view phân quyền)**:
  1. `v_public_hotel_listings` (**view phân quyền**): chỉ hiển thị khách sạn `APPROVED` và `is_active = TRUE`, **ẩn hoàn toàn** các cột nhạy cảm (`commission_rate`, `tax_code`, `bank_account`, `bank_name`) đối với khách hàng và truy vấn công khai.
  2. `v_hotel_daily_occupancy`: tổng hợp tỷ lệ lấp đầy (`booked_count / total_allotment`) theo khách sạn và ngày.
  3. `v_partner_settlement_overview`: tổng hợp doanh thu, hoa hồng và số tiền đã/chưa chi trả theo từng đối tác.
- **Trigger (≥ 02)**:
  1. `trg_validate_and_sync_review` (gồm kiểm tra trước khi chèn `reviews` — quy tắc liên bảng mà `CHECK` không diễn đạt được — và cập nhật `hotels.avg_rating`, `hotels.review_count` sau thay đổi).
  2. `trg_audit_log_changes` (gắn trên `bookings`, `hotels`, `partner_payouts`): tự động lưu `old_data`/`new_data` dạng `JSONB` vào `audit_logs`.
- **Chỉ mục (≥ 05, có composite và covering/partial index)**:
  1. Composite index: `idx_bookings_hotel_status_dates ON bookings(hotel_id, status, check_in_date, check_out_date)`.
  2. Partial index: `idx_bookings_active_holds ON bookings(hold_expires_at) WHERE status = 'HOLD'` (tối ưu tác vụ quét giải phóng đơn giữ chỗ hết hạn).
  3. Covering index (`INCLUDE`): `idx_inventory_avail_cover ON room_inventory(room_type_id, stay_date) INCLUDE (total_allotment, booked_count, held_count, nightly_price) WHERE is_closed = FALSE`.
  4. Composite index: `idx_bookings_customer_created ON bookings(customer_id, created_at DESC)`.
  5. GIN index (hoặc composite) phục vụ tìm kiếm/kiểm toán: `idx_audit_entity_time ON audit_logs(entity_type, entity_id, created_at DESC)` và `idx_hotels_location_rating ON hotels(location_id, star_rating, avg_rating DESC) WHERE approval_status = 'APPROVED' AND is_active = TRUE`.

## **4  Danh mục 20 truy vấn nghiệp vụ minh họa**

| Mã | Câu hỏi nghiệp vụ | Kỹ thuật SQL áp dụng |
| :---- | :---- | :---- |
| Q01 | Tìm các loại phòng còn đủ số lượng cho toàn bộ đêm trong khoảng `[check_in, check_out)` tại một địa điểm. | `JOIN ≥ 3 bảng`, `NOT EXISTS` (bảo đảm không có đêm nào thiếu phòng hoặc đóng bán). |
| Q02 | Liệt kê tất cả khách sạn đã duyệt kèm số lượng đánh giá và đơn đặt (kể cả khách sạn chưa có đơn nào). | `LEFT OUTER JOIN`, `COUNT`, `COALESCE`. |
| Q03 | Chi tiết đầy đủ một đơn đặt phòng gồm khách sạn, hạng phòng, từng đêm giá snapshot và giao dịch thanh toán. | `JOIN ≥ 4 bảng`, tổng hợp theo hạng mục. |
| Q04 | Tìm toàn bộ khách sạn nằm trong một tỉnh/thành phố và mọi quận/huyện/phường trực thuộc. | **CTE đệ quy** (`WITH RECURSIVE`) trên cây `locations`. |
| Q05 | Lọc các khách sạn có từ 10 đánh giá hiển thị trở lên và điểm trung bình ≥ 4.5. | `GROUP BY` + `HAVING`. |
| Q06 | Xếp hạng các khách sạn theo tổng doanh thu thuần trong từng thành phố. | `CTE`, **Window function** (`DENSE_RANK() OVER (PARTITION BY ...)`). |
| Q07 | Tìm khách hàng có tổng chi tiêu lớn hơn mức chi tiêu trung bình của khách đặt cùng hạng sao khách sạn. | **Truy vấn con tương quan** (correlated subquery). |
| Q08 | Tính doanh thu gộp, doanh thu ròng sau hoàn tiền và hoa hồng sàn theo từng tháng và từng phương thức thanh toán. | `JOIN ≥ 3 bảng`, `DATE_TRUNC`, `FILTER (WHERE ...)`. |
| Q09 | Tìm các loại phòng có số ngày hết phòng (`booked_count = total_allotment`) vượt quá 15 ngày trong tháng cao điểm. | `GROUP BY` + `HAVING`, biểu thức điều kiện. |
| Q10 | Tính doanh thu lũy kế theo ngày trong tháng của một đối tác cụ thể. | `SUM() OVER (ORDER BY ...)` (**Window function**). |
| Q11 | Tìm các khách sạn sở hữu **tất cả** các tiện ích bắt buộc trong danh sách khách chọn (ví dụ: Wifi, Hồ bơi, Bãi đỗ xe). | **Phép chia quan hệ** (`NOT EXISTS` kép hoặc `GROUP BY + HAVING COUNT = N`). |
| Q12 | Liệt kê những khách sạn chưa từng bị mở ticket khiếu nại nào trong 6 tháng gần nhất. | `NOT EXISTS` kết hợp lọc khoảng thời gian. |
| Q13 | Thống kê tỷ lệ hủy đơn (%) và tổng tiền phạt giữ lại theo từng khách sạn có tối thiểu 20 đơn. | `JOIN ≥ 3 bảng`, `GROUP BY + HAVING`, chia thập phân an toàn `NULLIF`. |
| Q14 | So sánh công suất phòng thực tế của từng đối tác so với công suất trung bình toàn sàn trong quý. | `CTE` nhiều bước, phép so sánh tổng hợp. |
| Q15 | Danh sách các đơn `COMPLETED` đủ điều kiện đưa vào kỳ đối soát mới nhưng chưa từng được chi trả. | `LEFT JOIN ... WHERE payout_items.booking_id IS NULL` hoặc `NOT EXISTS`. |
| Q16 | Thời gian phản hồi và giải quyết trung bình của từng Nhân viên Hỗ trợ Khách hàng trên các ticket đã đóng. | `JOIN`, `EXTRACT(EPOCH FROM ...)`, `GROUP BY + HAVING`. |
| Q17 | Thống kê mức độ sử dụng và tổng số tiền tài trợ của từng mã khuyến mãi sàn. | `LEFT OUTER JOIN`, `SUM`, `COUNT`. |
| Q18 | Kiểm tra đối chiếu chênh lệch giữa `bookings.total_amount` và tổng `booking_night_rates` trừ `discount_amount`. | `JOIN`, `GROUP BY + HAVING` phát hiện sai lệch dữ liệu. |
| Q19 | Tìm các phòng vật lý đang trống (không gắn với đơn nào đang `CHECKED_IN`) theo từng loại phòng của một khách sạn. | `JOIN ≥ 3 bảng`, `NOT EXISTS`. |
| Q20 | Truy vết lịch sử các thao tác nhạy cảm (hủy ngoại lệ, xác nhận payout) kèm thông tin người thực hiện trong 30 ngày. | `JOIN` `audit_logs` với `users`, khai thác trường `JSONB`. |

## **5  An toàn dữ liệu, phân quyền CSDL và phục hồi**

- **Phân quyền ở mức PostgreSQL (≥ 03 vai trò)**:
  - `db_migrator`: sở hữu schema, chạy Prisma Migrate và file SQL định nghĩa bảng/ràng buộc/hàm/trigger.
  - `app_rw`: tài khoản kết nối của Express backend; chỉ được `SELECT, INSERT, UPDATE` trên các bảng nghiệp vụ cần thiết, `EXECUTE` trên các `PROCEDURE`/`FUNCTION`; bị `REVOKE` quyền `DROP`, `ALTER`, `TRUNCATE` và bị chặn `DELETE` trên `payments`, `payout_items`, `audit_logs`.
  - `reporting_ro`: chỉ được `SELECT` trên các view báo cáo (`v_public_hotel_listings`, `v_hotel_daily_occupancy`, `v_partner_settlement_overview`); không được truy cập trực tiếp bảng `users` (`password_hash`) hay thông tin ngân hàng nhạy cảm.
- **Bảo mật tầng ứng dụng**: Băm mật khẩu bằng `bcrypt` (hoặc `Argon2`); Prisma ORM và truy vấn SQL thô đều dùng tham số hóa (`$1, $2` / `Prisma.sql`), không ghép chuỗi SQL; mật khẩu DB, JWT secret, Redis URL lưu trong `.env` (không commit mã nguồn, chỉ giữ `.env.example`).
- **Sao lưu và phục hồi**: Viết script `backup.sh` dùng `pg_dump -Fc` xuất file `.dump` và `restore.sh` dùng `pg_restore` vào CSDL sạch. Kịch bản kiểm chứng: tạo bản backup chuẩn → giả lập xóa nhầm bảng/dữ liệu trên môi trường test → thực thi `restore.sh` → đối chiếu số bảng, tổng dòng, tổng doanh thu và số tiền payout khớp 100% trước sự cố.

# **VI  KIẾN TRÚC VÀ THIẾT KẾ ỨNG DỤNG**

## **1  Kiến trúc tổng thể**

Luồng xử lý: **Client (React) → REST API (Express + Prisma ORM) → Cache (Redis) & CSDL (PostgreSQL)**. Trình duyệt không kết nối trực tiếp tới PostgreSQL hay Redis.

Frontend React tổ chức theo 05 phân hệ tương ứng 05 tác nhân: Cổng Khách hàng (tìm kiếm, đặt phòng, quản lý đơn, đánh giá, gửi ticket), Cổng Đối tác (quản lý khách sạn, quỹ phòng/giá theo ngày, check-in/out, đối soát doanh thu), Cổng Hỗ trợ (hàng đợi ticket, xử lý tranh chấp, kiểm duyệt review), Cổng Kế toán (tạo kỳ đối soát, duyệt/chi trả payout, báo cáo tài chính) và Cổng Quản trị (duyệt đối tác/khách sạn, địa điểm, tiện ích, khuyến mãi, nhật ký).

Backend Express tổ chức phân lớp `routes → middlewares (auth/RBAC/validation) → controllers → services → repositories (Prisma + raw SQL cho stored procedure/truy vấn phức tạp)`. Redis làm lớp cache cho API tìm kiếm, cây địa điểm và kiểm soát khóa tạm/rate-limit. Tài liệu API được xuất tự động/đồng bộ qua **OpenAPI / Swagger UI** tại `/api-docs`.

## **2  Giao diện dự kiến**

- Giao diện Khách hàng (A03): Trang chủ tìm kiếm theo khu vực/ngày/số khách/tiện ích; trang danh sách khách sạn và chi tiết phòng trống; trang thanh toán mô phỏng và đếm ngược giữ chỗ; trang quản lý đơn của tôi, viết đánh giá và gửi ticket hỗ trợ.
- Giao diện Đối tác (A02): Dashboard công suất và doanh thu; màn hình quản lý khách sạn, loại phòng, phòng vật lý; ma trận lịch cập nhật giá và `total_allotment` theo ngày; danh sách check-in/check-out và xem phiếu đối soát payout.
- Giao diện Hỗ trợ Khách hàng (A04): Danh sách ticket lọc theo trạng thái/mức độ; khung trao đổi đa bên (kèm ghi chú nội bộ); màn hình xử lý hủy ngoại lệ và danh sách kiểm duyệt đánh giá.
- Giao diện Kế toán Sàn (A05): Màn hình khởi tạo kỳ đối soát, xem chi tiết các đơn `COMPLETED` hợp lệ, danh sách `partner_payouts` chờ chi trả, nút xác nhận thanh toán và báo cáo tài chính.
- Giao diện Quản trị viên (A01): Màn hình duyệt hồ sơ đối tác/khách sạn, quản lý cây địa điểm, tiện ích, khuyến mãi, tài khoản nhân sự nội bộ và nhật ký `audit_logs`.

## **3  Nhóm API tiêu biểu (kèm OpenAPI/Swagger)**

| Phương thức và đường dẫn | Mục đích và kiểm soát chính |
| :---- | :---- |
| `POST /api/auth/register`, `POST /api/auth/login` | Đăng ký và đăng nhập cho 05 tác nhân; trả JWT chứa `userId` và `role`. |
| `GET /api/locations/tree`, `GET /api/amenities` | Lấy cây địa điểm phân cấp và danh mục tiện ích (ưu tiên đọc từ Redis cache). |
| `GET /api/hotels/search` | Tìm khách sạn còn phòng theo ngày/khách/tiện ích (Redis cache ngắn hạn + SQL kiểm tra `room_inventory`). |
| `POST /api/bookings/hold` | Gọi `sp_create_booking_hold` qua Prisma `$executeRaw`; tạo đơn giữ phòng có TTL. |
| `POST /api/bookings/:id/pay` | Xác nhận thanh toán mô phỏng; bắt buộc `Idempotency-Key`; chuyển `held_count` → `booked_count`. |
| `POST /api/bookings/:id/cancel` | Hủy đơn theo chính sách; tính hoàn tiền và trả phòng về `room_inventory`. |
| `POST /api/bookings/:id/check-in`, `check-out` | Đối tác (A02) gán phòng vật lý hoặc hoàn tất đơn; kiểm tra quyền sở hữu khách sạn. |
| `POST /api/bookings/:id/reviews` | Khách hàng (A03) đánh giá đơn `COMPLETED` của chính mình; trigger đồng bộ điểm khách sạn. |
| `POST /api/partner/inventory/bulk` | Đối tác (A02) cập nhật giá và quỹ phòng theo khoảng ngày; vô hiệu hóa cache Redis liên quan. |
| `POST /api/tickets`, `PATCH /api/tickets/:id/resolve` | Tạo ticket (A02/A03) và xử lý tranh chấp/hủy ngoại lệ (A04). |
| `POST /api/accounting/settlements`, `POST .../pay` | Kế toán (A05) chốt kỳ đối soát (`sp_generate_settlement_batch`) và xác nhận chi trả payout. |
| `PATCH /api/admin/partners/:id/approve` | Quản trị viên (A01) phê duyệt hồ sơ đối tác và kích hoạt hiển thị khách sạn. |
| `GET /api/reports/overview` | Báo cáo thống kê theo vai trò (A01, A02, A05); khai thác view và truy vấn Q01–Q20. |

Tối thiểu ≥ 06 nghiệp vụ chính được cài đặt qua Prisma ORM (`hotels`, `room_types`, `bookings`, `reviews`, `support_tickets`, `promotions`...) và gọi ≥ 01 thủ tục lưu trữ (`sp_create_booking_hold` / `sp_confirm_booking_payment`) từ backend.

## **4  Quy ước triển khai và đóng gói Docker Compose**

Frontend không tự tính tổng tiền thanh toán hoặc số tiền hoàn hủy; backend và các hàm/thủ tục PostgreSQL là nguồn chân lý duy nhất. Mọi đầu vào từ client được kiểm tra schema (Zod/Joi), lỗi nghiệp vụ trả HTTP status chuẩn (`400`, `401`, `403`, `404`, `409` khi xung đột hết phòng/trạng thái).

Cấu trúc thư mục dự án gồm `client/` (React), `server/` (Express + Prisma + Swagger + Testcontainers tests), `database/` (SQL thủ tục, hàm, view, trigger, roles, seed scripts, backup/restore) và `docker-compose.yml` ở thư mục gốc. File `docker-compose.yml` cấu hình đầy đủ dịch vụ `postgres`, `redis`, `server` và `client`, cho phép một lệnh `docker compose up` trên máy sạch tự khởi tạo PostgreSQL + Redis, chạy Prisma Migrate + SQL nâng cao, nạp dữ liệu mẫu và khởi động cả backend lẫn frontend.

# **VII  KẾ HOẠCH THỰC HIỆN**

## **Tiến độ dự kiến trong 08 tuần (nhóm 05 thành viên)**

Phân công vai trò phối hợp trong nhóm 05 thành viên:
- **Thành viên 1 (Trưởng nhóm / Kiến trúc CSDL)**: Thiết kế ERD, chuẩn hóa 3NF, từ điển dữ liệu, viết script SQL thủ tục/hàm/trigger/view/chỉ mục và phân quyền DB.
- **Thành viên 2 (Backend Core & Prisma/Redis)**: Dựng Express, Prisma schema/migration, tích hợp Redis cache/lock, luồng tìm kiếm và giữ/đặt/thanh toán/hủy phòng, OpenAPI/Swagger.
- **Thành viên 3 (Backend Nghiệp vụ & Kiểm thử)**: Phát triển luồng đối tác, hỗ trợ ticket (A04), kế toán đối soát (A05), báo cáo Q01–Q20 và bộ kiểm thử tự động Testcontainers (≥ 15 ca).
- **Thành viên 4 (Frontend Khách hàng & Đối tác)**: Xây dựng giao diện React cho A03 (tìm kiếm, đặt phòng, đánh giá, ticket) và A02 (quản lý phòng, lịch giá/tồn, check-in/out).
- **Thành viên 5 (Frontend Nội bộ, Dữ liệu mẫu & Vận hành)**: Xây dựng giao diện React cho A01, A04, A05; viết script seed ≥ 10.000/100.000 bản ghi tiếng Việt; kịch bản đồng thời k6/SQL, `EXPLAIN ANALYZE`, backup/restore và `docker compose`.

| Tuần | Nội dung thực hiện | Sản phẩm và điều kiện hoàn thành |
| :---- | :---- | :---- |
| 1 | Chốt 05 tác nhân A01–A05, 22 use case, 18 BR, quy tắc tính tiền/hoa hồng/hoàn hủy và ma trận truy vết. | Đặc tả UC01–UC22; phân quyền đủ 05 tác nhân; BR01–BR18; ví dụ tính tiền đối chứng. |
| 2 | Thiết kế ERD ≥ 10 thực thể (đủ 1–1, 1–N, N–N, phân cấp, thực thể yếu); chứng minh 3NF; từ điển dữ liệu. | Lược đồ 22 bảng; chứng minh 3NF ≥ 03 bảng; thuyết minh cột phi chuẩn hóa; từ điển 100% cột (**Mốc M1**). |
| 3 | Dựng `docker-compose.yml` (PostgreSQL, Redis); tạo schema bằng Prisma Migrate + SQL constraint/trigger/view/SP/function/roles; script seed ≥ 10.000 `bookings`. | Migration chạy từ CSDL trống; đủ PK/FK (`ON DELETE/UPDATE`), UNIQUE, CHECK, NOT NULL, DEFAULT; seed có tiếng Việt đúng ràng buộc. |
| 4 | Lập trình Express API xác thực 05 tác nhân, Swagger, quản lý đối tác/phòng/tồn ngày, tìm kiếm (Redis) và giữ/đặt phòng (`sp_create_booking_hold`). | Luồng tìm kiếm – giữ phòng – đặt phòng chạy qua Prisma + thủ tục; thử nghiệm đặt trùng phòng bị chặn (**Mốc M2**). |
| 5 | Hoàn thiện luồng thanh toán chống lặp, hủy hoàn tiền, check-in/out, đánh giá, ticket hỗ trợ (A04) và chốt kỳ đối soát payout (A05). | Giao dịch thu/hoàn/đối soát nguyên tử; đối soát không sai lệch công nợ; chạy đủ ≥ 06 nghiệp vụ qua Prisma (**Mốc M3**). |
| 6 | Tích hợp giao diện React đủ 05 tác nhân; hoàn thiện và kiểm tra 20 truy vấn nghiệp vụ Q01–Q20 cùng 03 view phân quyền/báo cáo. | Demo xuyên suốt F01–F08 trên giao diện React; kết nối đúng API và kiểm soát quyền truy cập ở cả UI lẫn backend. |
| 7 | Sinh bộ dữ liệu hiệu năng ≥ 100.000 dòng (`room_inventory` & `bookings`); viết ≥ 15 test Testcontainers; đo `EXPLAIN ANALYZE`; demo lỗi đồng thời (k6/2 phiên SQL); backup/restore. | Đạt ngưỡng bản ghi; báo cáo thời gian thực thi trước/sau ≥ 05 chỉ mục cho ≥ 03 truy vấn chậm; tái hiện & khắc phục overbooking; phục hồi dữ liệu thành công (**Mốc M4**). |
| 8 | Hoàn thiện báo cáo cuối kỳ, hình ERD chuẩn, tài liệu từ điển, slide, kịch bản bảo vệ và kiểm tra chạy sạch bằng `docker compose up`. | Chạy sạch trên máy mới bằng `docker compose up`; bộ mã nguồn, script SQL, test và báo cáo khớp 100% (**Mốc M5**). |

# **VIII  KẾ HOẠCH KIỂM THỬ VÀ NGHIỆM THU**

## **1  Dữ liệu kiểm thử**

Dữ liệu sinh hoàn toàn bằng script (Node.js/TypeScript hoặc SQL), sử dụng tên người Việt, địa danh Việt Nam, tên khách sạn/mô tả phòng có tiếng Việt có dấu, không dùng dữ liệu cá nhân thật và tuân thủ 100% ràng buộc toàn vẹn. Dữ liệu chia thành hai profile bắt buộc bên cạnh bộ demo nhỏ:

| Bộ dữ liệu | Quy mô tối thiểu | Mục đích và điều kiện |
| :---- | :---- | :---- |
| Bộ nghiệp vụ | `bookings ≥ 10.000` dòng; `room_inventory ≥ 30.000` dòng; `hotels ≥ 50`; `users ≥ 1.500`; `booking_items ≥ 12.000`. | Kiểm thử luồng nghiệp vụ xuyên suốt, ràng buộc FK/CHECK/trigger, đối soát tài chính và toàn bộ bộ test tự động. |
| Bộ hiệu năng | `bookings ≥ 100.000` dòng; `room_inventory ≥ 100.000` dòng (ví dụ 100 khách sạn × 3 loại phòng × 365 ngày = 109.500 dòng); `booking_night_rates ≥ 200.000` dòng. | Đo hiệu năng truy vấn tìm kiếm phòng trống, thống kê báo cáo và đánh giá `EXPLAIN ANALYZE` trước/sau chỉ mục trên bảng nghiệp vụ thật. |
| Phân bố dữ liệu | Trải dài 12 tháng; đủ 04 trạng thái lưu trú, đơn hủy miễn phí/phạt, đơn có đánh giá, ticket khiếu nại và các kỳ đã/chưa chi trả payout. | Bảo đảm các truy vấn `GROUP BY`, `HAVING`, `NOT EXISTS`, `CTE` đệ quy đều trả về kết quả có ý nghĩa thực tế. |

## **2  Kịch bản kiểm thử trọng yếu (Testcontainers, Đồng thời & Nghiệp vụ)**

Bộ kiểm thử tự động tầng dữ liệu viết bằng Jest/Vitest kết hợp **Testcontainers (PostgreSQL thật)** với ≥ 15 ca tự động (T01–T15), cộng thêm các kịch bản kiểm thử đồng thời (k6/JMeter/2 phiên SQL song song), hiệu năng và phục hồi (T16–T20):

| Mã | Tình huống kiểm thử | Kết quả mong đợi |
| :---- | :---- | :---- |
| T01 | Vi phạm CHECK: đặt phòng với `check_out_date <= check_in_date` hoặc `rating = 6`. | PostgreSQL từ chối với lỗi check constraint (`23514`). |
| T02 | Vi phạm CHECK tồn kho: cập nhật `booked_count + held_count > total_allotment`. | PostgreSQL từ chối giao dịch, không để âm quỹ phòng. |
| T03 | Vi phạm FK & `ON DELETE RESTRICT`: xóa loại phòng hoặc booking đã phát sinh thanh toán/payout. | PostgreSQL từ chối (`23503`), bảo vệ toàn vẹn lịch sử tài chính. |
| T04 | Vi phạm UNIQUE thực thể yếu & 1–1: chèn trùng `(booking_id, line_no)` hoặc tạo 2 đánh giá cho 1 booking. | Từ chối vi phạm khóa duy nhất (`23505`); khác `line_no` trên cùng đơn vẫn hợp lệ. |
| T05 | Kiểm tra trigger nghiệp vụ: khách hàng tạo đánh giá khi đơn mới ở trạng thái `CONFIRMED`. | Trigger `BEFORE INSERT` chặn và ném ngoại lệ nghiệp vụ. |
| T06 | Kiểm tra trigger đồng bộ phi chuẩn hóa: thêm/ẩn đánh giá qua `moderation_status = 'HIDDEN'`. | `hotels.avg_rating` và `hotels.review_count` tự cập nhật khớp tuyệt đối với bảng `reviews`. |
| T07 | Kiểm tra trigger audit: đổi trạng thái duyệt khách sạn hoặc xác nhận payout. | Bảng `audit_logs` tự ghi nhận bản ghi chứa `old_data` và `new_data` JSONB. |
| T08 | Gọi thủ tục `sp_create_booking_hold` với khoảng ngày có 1 đêm ở giữa đã đóng (`is_closed = TRUE`). | Thủ tục rollback toàn bộ, không giữ chỗ cho các đêm còn lại. |
| T09 | Thử nghiệm đồng thời (k6 / 2 phiên SQL song song): 10 luồng cùng đặt 01 phòng trống cuối cùng. | Tái hiện lỗi lost update khi bỏ khóa; sau khi bật `FOR UPDATE` + `CHECK`, đúng 01 luồng thành công, 09 luồng nhận lỗi hết phòng. |
| T10 | Gửi lại yêu cầu thanh toán trùng `idempotency_key` (network retry). | Chỉ sinh đúng 01 bản ghi `payments`, không trừ hoặc chuyển trạng thái lặp. |
| T11 | Hủy đơn trước mốc `free_cancel_hours` và hủy đơn sau mốc miễn phí hủy. | Hoàn 100% hoặc tính đúng `penalty_percent`; tồn kho `room_inventory` được hoàn trả đầy đủ. |
| T12 | Chốt kỳ đối soát hai lần liên tiếp cho cùng khoảng ngày chứa các đơn `COMPLETED`. | Kỳ thứ nhất tạo payout thành công; kỳ thứ hai bỏ qua các đơn đã nằm trong `payout_items`, không chi trả trùng. |
| T13 | Kiểm tra phân quyền DB (`reporting_ro` / `app_rw`) và view phân quyền `v_public_hotel_listings`. | Truy vấn từ `reporting_ro` không xem được `password_hash`, `tax_code`, `bank_account` và không xóa được `payments`. |
| T14 | Kiểm tra giá snapshot khi đối tác tăng giá phòng lên gấp đôi ngay sau khi khách vừa tạo đơn. | Số tiền trên `bookings` và `booking_night_rates` giữ nguyên giá cũ bất biến. |
| T15 | Kiểm tra xử lý ticket (A04): khách hàng gọi API đọc ghi chú nội bộ (`is_internal_note = TRUE`). | API trả về chỉ các tin nhắn công khai, ẩn ghi chú nội bộ và chặn sửa ticket của người khác. |
| T16 | Kiểm chứng seed dữ liệu hai profile: đếm `COUNT(*)` trên `bookings` và `room_inventory`. | Bộ nghiệp vụ ≥ 10.000 `bookings`; bộ hiệu năng ≥ 100.000 dòng, có dữ liệu tiếng Việt hợp lệ. |
| T17 | Đo `EXPLAIN (ANALYZE, BUFFERS)` trước và sau chỉ mục cho ≥ 03 truy vấn chậm (tìm phòng trống, xếp hạng doanh thu, CTE đệ quy). | Thời gian thực thi và số buffers đọc giảm rõ rệt sau khi tạo 05+ chỉ mục (composite, covering/partial). |
| T18 | Chạy `backup.sh`, xóa nhầm bảng/dữ liệu trên CSDL kiểm thử, chạy `restore.sh`. | Khôi phục đầy đủ bảng, dòng, tổng doanh thu và số liệu đối soát khớp 100%. |
| T19 | Kiểm tra đối chiếu từ điển dữ liệu với schema PostgreSQL thực tế. | 100% cột của 22 bảng khớp tên, kiểu, ràng buộc, giá trị mặc định và ví dụ. |
| T20 | Triển khai sạch bằng `docker compose up --build` trên máy mới chưa có dữ liệu. | Tự dựng PostgreSQL, Redis, chạy migration, seed, Swagger UI và giao diện React hoạt động đầy đủ. |

## **3  Tiêu chí nghiệm thu**

Hoàn thành đầy đủ 05 tác nhân A01–A05, F01–F08, UC01–UC22 và BR01–BR18. ERD có ≥ 10 thực thể, đủ quan hệ 1–1, 1–N, N–N, phân cấp địa điểm và thực thể yếu; mọi bảng đạt ≥ 3NF và chứng minh qua phụ thuộc hàm cho ≥ 03 bảng kèm thuyết minh các cột phi chuẩn hóa. Migration tạo đủ 22 bảng vật lý kèm đầy đủ PK, FK (`ON DELETE/UPDATE`), `UNIQUE`, `CHECK`, `NOT NULL`, `DEFAULT`; từ điển bao phủ 100% cột.

Đáp ứng trọn vẹn khối lượng SQL và ứng dụng: bộ dữ liệu ≥ 10.000 `bookings` và ≥ 100.000 dòng ở bảng đo hiệu năng có tiếng Việt; ≥ 20 truy vấn đủ các phép toán yêu cầu (bao gồm CTE đệ quy, window function, phép chia/`NOT EXISTS`, truy vấn con tương quan, `GROUP BY + HAVING`, `OUTER JOIN`); ≥ 03 view (có view phân quyền); ≥ 03 stored procedure và ≥ 02 function; ≥ 02 trigger; ≥ 05 chỉ mục kèm đo `EXPLAIN ANALYZE`; minh chứng lỗi đồng thời và giải pháp; ≥ 03 vai trò CSDL; script backup/restore; ứng dụng React + Express + Prisma (≥ 06 nghiệp vụ ORM + gọi stored procedure) + Redis + Swagger; ≥ 15 ca test tự động với Testcontainers và `docker compose up` chạy sạch.

Các tiêu chí trên phục vụ kiểm soát nội bộ của nhóm 05 thành viên và đối chiếu với bảng ngưỡng tối thiểu của học phần.

# **IX  ĐỀ CƯƠNG CHI TIẾT BÁO CÁO CUỐI KỲ**

## **Chương 1  Tổng quan đề tài**

1.1 Bối cảnh bài toán đặt phòng khách sạn trực tuyến (mô hình OTA).  
1.2 Lý do lựa chọn đề tài và vai trò trọng tâm của cơ sở dữ liệu.  
1.3 Mục tiêu tổng quát và mục tiêu cụ thể theo chuẩn học phần.  
1.4 Đối tượng, phạm vi bắt buộc và giới hạn triển khai.  
1.5 Phương pháp thực hiện, phân công 05 thành viên và kết quả dự kiến.  
1.6 Cấu trúc báo cáo.

## **Chương 2  Khảo sát và phân tích yêu cầu**

2.1 Mô hình vận hành sàn đặt phòng đa đối tác.  
2.2 Đặc tả 05 tác nhân (Quản trị viên, Đối tác, Khách hàng, Hỗ trợ, Kế toán) và ma trận phân quyền.  
2.3 Quy trình tìm phòng, giữ chỗ, thanh toán, check-in/out, hủy hoàn tiền, hỗ trợ và đối soát hoa hồng.  
2.4 Yêu cầu chức năng (F01–F08) và yêu cầu phi chức năng.  
2.5 Sơ đồ và đặc tả đầy đủ 22 use case (UC01–UC22).  
2.6 Mười tám quy tắc nghiệp vụ (BR01–BR18), nguyên tắc tính tiền, hoa hồng và ví dụ đối chứng.  
2.7 Ma trận truy vết UC – BR – Dữ liệu – Kiểm thử.

## **Chương 3  Phân tích và thiết kế cơ sở dữ liệu**

3.1 Xác định ≥ 10 thực thể, thuộc tính, khóa và các loại quan hệ (1–1, 1–N, N–N, phân cấp, thực thể yếu).  
3.2 Sơ đồ ERD khái niệm và lược đồ quan hệ logic 22 bảng.  
3.3 Chuẩn hóa lược đồ ≥ 3NF; chứng minh phụ thuộc hàm và khóa ứng viên cho ≥ 03 bảng tiêu biểu.  
3.4 Thuyết minh phi chuẩn hóa có kiểm soát (`avg_rating`, `review_count`, snapshot giá) và cơ chế giữ nhất quán.  
3.5 Từ điển dữ liệu đầy đủ 100% cột (kiểu, ràng buộc, mặc định, ý nghĩa, ví dụ).  
3.6 Thiết kế vật lý, chính sách `ON DELETE/UPDATE` và quy trình migration (Prisma Migrate + SQL).  
3.7 Chỉ mục, view (có view phân quyền), stored procedure, function, trigger và xử lý giao dịch đồng thời.  
3.8 Bảo mật phân quyền ≥ 03 vai trò CSDL, chiến lược sao lưu và phục hồi.

## **Chương 4  Xây dựng ứng dụng và khai thác dữ liệu**

4.1 Kiến trúc tổng thể React, Express, Prisma, Redis và PostgreSQL.  
4.2 Tổ chức mã nguồn, cấu hình biến môi trường và triển khai `docker compose`.  
4.3 Thiết kế REST API, middleware phân quyền và tài liệu OpenAPI / Swagger.  
4.4 Giao diện người dùng cho 05 tác nhân và các luồng nghiệp vụ chính qua Prisma ORM + stored procedure.  
4.5 Tích hợp Redis cache danh mục/tìm kiếm và xử lý vô hiệu hóa cache khi cập nhật tồn phòng.  
4.6 Cài đặt và minh họa kết quả 20 truy vấn nghiệp vụ (Q01–Q20).

## **Chương 5  Kiểm thử và đánh giá**

5.1 Môi trường thử nghiệm và kịch bản sinh dữ liệu mẫu ≥ 10.000 / ≥ 100.000 bản ghi tiếng Việt.  
5.2 Kết quả ≥ 15 ca kiểm thử tự động tầng dữ liệu bằng Testcontainers (bao gồm ca vi phạm ràng buộc).  
5.3 Tái hiện và khắc phục lỗi đồng thời (overbooking / lost update) bằng k6 hoặc 2 phiên SQL song song.  
5.4 Kết quả đo `EXPLAIN ANALYZE / BUFFERS` trước và sau chỉ mục cho ≥ 03 truy vấn chậm.  
5.5 Trình diễn quy trình sao lưu và phục hồi sau sự cố xóa nhầm dữ liệu.  
5.6 Đánh giá đối chiếu toàn bộ tiêu chí nghiệm thu của học phần.

## **Chương 6  Kết luận và hướng phát triển**

6.1 Kết quả đạt được so với mục tiêu đề ra.  
6.2 Hạn chế còn tồn tại và bài học kinh nghiệm.  
6.3 Hướng phát triển: tích hợp cổng thanh toán thật, đồng bộ Channel Manager, hóa đơn điện tử, định giá động và trò chuyện thời gian thực.

# **X  SẢN PHẨM, RỦI RO VÀ TÀI LIỆU THAM KHẢO**

## **1  Sản phẩm bàn giao**

Bộ sản phẩm gồm: báo cáo cuối kỳ; sơ đồ ERD và lược đồ quan hệ kèm file nguồn; từ điển dữ liệu; Prisma schema, migration và các script SQL (view, stored procedure, function, trigger, chỉ mục, 20 truy vấn Q01–Q20, phân quyền role); script seed ≥ 10.000 và ≥ 100.000 bản ghi; mã nguồn React + Express + Redis; tài liệu OpenAPI/Swagger; bộ kiểm thử Testcontainers và kịch bản kiểm thử đồng thời; script `backup.sh`/`restore.sh` và minh chứng phục hồi; `docker-compose.yml` và `README.md` hướng dẫn chạy trên máy sạch; slide và kịch bản bảo vệ.

## **2  Rủi ro và phương án xử lý**

| Rủi ro | Ảnh hưởng | Phương án xử lý |
| :---- | :---- | :---- |
| Giao diện quá cồng kềnh làm chậm phần CSDL | Không kịp hoàn thành truy vấn, thủ tục, test và tối ưu chỉ mục. | Giữ giao diện React gọn, đủ dùng theo yêu cầu; ưu tiên hoàn thành sớm schema, seed, Q01–Q20, SP/trigger và test Testcontainers. |
| Lệch dữ liệu giữa Redis cache và PostgreSQL | Khách tìm thấy phòng ảo dù thực tế đã hết phòng. | Redis chỉ cache ngắn hạn danh sách tìm kiếm và invalidate khi cập nhật quỹ phòng; bước giữ/đặt phòng luôn khóa và kiểm tra trực tiếp PostgreSQL. |
| Xung đột giao dịch đồng thời gây deadlock | Giao dịch giữ/hủy phòng bị treo hoặc thất bại bất thường. | Khóa `room_inventory` theo thứ tự `(room_type_id, stay_date)` tăng dần, giữ transaction ngắn gọn, xử lý retry có giới hạn. |
| Lệch phiên bản giữa Prisma schema và SQL thuần (trigger/view/SP) | `prisma migrate` báo trôi schema (drift) hoặc mất thủ tục khi dựng mới. | Tách rõ custom SQL migration hoặc chạy script SQL khởi tạo sau `prisma migrate deploy` trong pipeline khởi động Docker. |
| Lỗi môi trường khi bảo vệ hoặc chạy máy sạch | Không trình diễn được demo hoặc thiếu dữ liệu mẫu. | Đóng gói đầy đủ vào `docker compose up`, kiểm thử dựng lại từ đầu trên máy sạch trước ngày bảo vệ ít nhất 03 ngày. |

## **3  Tài liệu tham khảo định hướng**

\[1\] PostgreSQL Global Development Group. *PostgreSQL Documentation: Constraints, Explicit Locking, Views, Triggers, Procedures*. https://www.postgresql.org/docs/current/

\[2\] Prisma Data, Inc. *Prisma ORM Documentation: Migrations, Transactions and Raw Queries*. https://www.prisma.io/docs

\[3\] Redis Ltd. *Redis Documentation: Caching and Distributed Locks*. https://redis.io/docs/latest/

\[4\] Testcontainers. *Testcontainers for Node.js — PostgreSQL Module*. https://node.testcontainers.org/

\[5\] OpenJS Foundation. *Express Documentation* & React Team. *React Documentation*. https://expressjs.com/ ; https://react.dev/

\[6\] Grafana Labs. *k6 Load Testing Documentation*. https://grafana.com/docs/k6/latest/

Ngày truy cập các tài liệu trực tuyến \[1\]–\[6\]: 16/11/2026.

Bổ sung giáo trình Cơ sở dữ liệu và tài liệu hướng dẫn học phần của Trường Đại học Công nghệ Giao thông Vận tải (UTT) theo danh mục giảng viên cung cấp khi hoàn thiện báo cáo chính thức.

**Giảng viên hướng dẫn                                  Đại diện nhóm thực hiện**

(Ký và ghi rõ họ tên)                                      (Ký và ghi rõ họ tên)
