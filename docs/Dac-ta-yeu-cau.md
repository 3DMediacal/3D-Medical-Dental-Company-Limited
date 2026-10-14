# Đặc tả yêu cầu — Mở rộng HR app theo mẫu TaskFlow (quản lý bằng BSC/OKR)

Nguồn: 154 ảnh TaskFlow + các form hỏi đáp ngày 14/10/2026. File chính: `index.html` (giữ một file). Giao diện giữ chuẩn hiện tại của app.

## Bố cục đã chọn
- Kanban: thanh lọc nằm ngang trên cùng, các cột trạng thái bên dưới.
- Chi tiết nhiệm vụ: ngăn kéo bên phải, một cột cuộn dọc.
- Danh sách dự án: lưới thẻ.
- Bảng lương: thẻ số liệu → tab → bảng (như TaskFlow).
- Phân quyền: chọn nhân viên → thẻ theo từng màn hình.
- Phiếu lương trên điện thoại: thực lĩnh nằm trên cùng, chi tiết bên dưới.
- Thẻ dự án: tên, thanh %, ảnh đại diện thành viên.
- Gắn nhiệm vụ vào KR: ô chọn KR + ô nhập trọng số %.
- Ô ngày trên Lịch tháng: tối đa 2 mục, phần còn lại hiện "+N mục".
- Kỳ lương đã chốt: băng thông báo phía trên bảng, có nút Mở khóa.
- Số tiền lương: che bằng •••, bấm vào từng ô để xem.

## Thứ tự làm
1. Vai trò, phân quyền, tài khoản, nhật ký thao tác (audit)
2. Dự án, Kanban, Lịch, gắn nhiệm vụ vào KR
3. Nền tảng lương + điểm BSC → hệ số
4. Kỳ lương, tạm ứng, xuất file, phát hành phiếu, kiểm tra vận hành
5. Thông báo, Gemini, trang Tổng quan, lớp lưu dữ liệu Supabase

Giao cả 5 giai đoạn một lượt; tôi tự kiểm tra từng vai trò trước khi giao.

## 1. Vai trò, phân quyền, tài khoản
- Vai trò: Owner, Admin, Giám đốc, HR, Trưởng phòng, Trưởng nhóm, Nhân viên, Kế toán.
- Mô hình quyền: theo vai trò, cộng thêm quyền ghi đè cho từng nhân viên.
- Quyền thao tác trên mỗi màn hình: Xem, Thêm, Sửa, Xóa, Duyệt, Xuất dữ liệu, Mở khóa kỳ.
- Chỉ Admin được sửa phân quyền. Owner/Admin luôn có toàn quyền.
- Kế toán: xuất file chuyển khoản, đánh dấu đã thanh toán, ngân sách dự án.
- Giám đốc: thấy tổng quỹ lương, không thấy lương từng người. Trưởng phòng: thấy tổng quỹ lương của phòng mình.
- Đăng nhập bằng tên đăng nhập (= mã nhân viên) + mật khẩu. Mật khẩu tối thiểu 8 ký tự, bắt đổi ở lần đăng nhập đầu. Khóa tài khoản sau 5 lần nhập sai.
- Xóa tài khoản = khóa đăng nhập, giữ hồ sơ và lịch sử.
- Tự đăng xuất sau 30 phút không hoạt động; nhập lại mật khẩu khi mở Bảng lương.
- Ủy quyền duyệt khi vắng: tối đa 14 ngày, không bao gồm duyệt lương.
- Audit: ghi mọi thao tác thêm/sửa/xóa ở mọi màn hình, lưu 5 năm.
- Hai người cùng sửa một bản ghi: khóa bản ghi khi đang sửa, tự mở khóa sau 5 phút.

## 2. Công việc
- Thanh điều hướng nhóm theo: Tổng quan · Quản lý · Công việc · Lương · Hệ thống. Header có nút "+ Tạo nhiệm vụ".
- **Dự án**: tên, mô tả, chủ trì, thành viên, ngày bắt đầu/kết thúc, ngân sách, khách hàng, phòng ban, gắn Objective/KR. % tiến độ tự tính từ nhiệm vụ.
  - Trạng thái: Lên kế hoạch · Đang chạy · Tạm dừng · Hoàn thành · Hủy.
  - Chế độ xem: danh sách, Kanban theo dự án, Gantt/timeline, chi tiết dự án + nhiệm vụ, báo cáo ngân sách kế hoạch so với thực chi.
  - Chỉ thành viên dự án và quản lý thấy được dự án.
- **Nhiệm vụ**: ưu tiên Khẩn/Cao/TB/Thấp; checklist con, bình luận, đính kèm file, nhiệm vụ lặp lại, nhiều người thực hiện, theo dõi giờ làm, nhãn.
  - Ai giao được nhiệm vụ: theo quyền Thêm của màn hình Nhiệm vụ.
  - Chi tiết mở trong ngăn kéo bên phải.
- **Kanban**: trạng thái mặc định Cần làm · Đang làm · Chờ duyệt · Chờ xử lý · Hoàn thành; Admin thêm/sửa tên/màu/thứ tự trạng thái; kéo-thả.
  - Thẻ hiện: ưu tiên, dự án, KR được gắn, người thực hiện, hạn/quá hạn, % checklist, nhãn.
  - Bộ lọc thời gian: Tất cả, Hôm nay, Tuần này, Tuần trước, Tháng này, Tháng trước, Quý này, khoảng ngày tùy chọn. Lọc thêm theo người thực hiện, trạng thái, dự án.
  - Phân trang 50 dòng. Tự lưu trữ nhiệm vụ đã hoàn thành sau 90 ngày.
- **Gắn vào KR**: mỗi nhiệm vụ gắn 1 KR và có trọng số %. KR = tổng trọng số các nhiệm vụ đã xong. Chỉ tính vào KR sau khi người giao duyệt. Hoàn thành trễ hạn chỉ cảnh báo, vẫn tính.
- Nhắc trước hạn 7 ngày.
- Nhiệm vụ nhiều người làm: mỗi người được cộng đủ trọng số vào KR của mình.
- Nhiệm vụ lặp lại: chỉ tính vào KR khi đã hoàn thành đủ mọi lần lặp trong kỳ.
- Giờ làm ghi trên nhiệm vụ không liên quan tới OT.
- Thực chi dự án: nhập khoản chi thủ công trong dự án, Kế toán duyệt.
- **Lịch**: hạn nhiệm vụ, mốc dự án, hạn KR/kỳ OKR, nghỉ phép, họp, sinh nhật. Chế độ xem Tháng, Tuần, Ngày, Danh sách.

## 3. OKR / BSC
- Kỳ tính lương theo tháng.
- Phân tầng Objective: công ty → phòng → cá nhân, hiển thị dạng danh sách thụt lùi.
- Check-in KR 2 tuần/lần, có mức tự tin xanh/vàng/đỏ. Không check-in đúng hạn thì nhắc và báo quản lý.
- Trọng số 4 trục BSC đặt riêng theo phòng: Trưởng phòng đề xuất, HR/Giám đốc duyệt. Cảnh báo khi tổng trọng số khác 100%.
- Quy trình chấm: Nhân viên tự chấm → Quản lý duyệt → HR khóa.
- Mỗi KR thuộc 1 trục BSC. Điểm trục = trung bình các KR trong trục. Điểm tổng = tổng (điểm trục × trọng số trục của phòng).
- Điểm dùng để tính hệ số = trung bình điểm tự chấm và điểm quản lý.
- Sửa KR sau khi khóa: Admin mở lại kỳ OKR; nếu kỳ lương chưa chốt thì tính lại lương.

## 4. Lương
- **Quy đổi BSC → lương**: điểm BSC tổng → hệ số nhân với lương năng suất. Ngưỡng: ≥95% → 1 · ≥85% → 0,75 · ≥70% → 0,5 · dưới 70% → 0. Chưa có điểm thì hệ số = 0 và chặn chốt kỳ.
- Điểm BSC và hệ số in trên phiếu lương của nhân viên.
- **Khoản lương mặc định** (HR thêm được): lương cơ bản, lương năng suất (× hệ số BSC), phụ cấp ăn ca, phụ cấp điện thoại/xăng xe, chuyên cần, thưởng, hoa hồng, OT.
- **Bảng ngạch/bậc**: tạo trống để HR tự nhập.
- **Hồ sơ lương**: có ngày hiệu lực. Hợp đồng lao động tự tạo/cập nhật hồ sơ lương.
  - Loại hợp đồng: thử việc, xác định thời hạn, không xác định thời hạn, cộng tác viên, thời vụ.
  - Cảnh báo hợp đồng/thử việc sắp hết hạn trước 30 ngày.
- **Thử việc**: 85% lương chính thức, khấu trừ TNCN 10%. Cộng tác viên khấu trừ 10%.
- **OT**: ngày thường 150% · cuối tuần 200% · lễ 300%. Lịch lễ Việt Nam có sẵn, Admin sửa được.
- **BHXH**: nhập riêng một mức lương đóng BHXH. NLĐ 10,5% / DN 21,5%.
- **TNCN**: biểu 5 bậc (5% đến 10tr · 10% đến 30tr · 20% đến 60tr · 30% đến 100tr · 35% trên đó). Giảm trừ bản thân 15,5tr, người phụ thuộc 6,2tr/người.
- **Ngày công**: lấy từ màn hình Chấm công hoặc import file máy chấm công. Chốt công ngày 25.
- Đi trễ/về sớm: không trừ, chỉ ghi nhận. Nghỉ không lương: trừ cả ngày công lẫn phụ cấp.
- Tăng/giảm lương giữa tháng: tính theo tỷ lệ số ngày trước/sau ngày hiệu lực.
- Nghỉ việc giữa tháng: tính lương đến ngày nghỉ, không có lương năng suất. Phép tồn quy ra tiền = lương cơ bản / công chuẩn × số ngày.
- **Hoa hồng**: HR nhập theo tháng, Giám đốc duyệt.
- **Ghi nhận thành tích**: mỗi quản lý có ngân sách thưởng/tháng, HR duyệt, chuyển vào khoản thưởng.
- **Lương tháng 13**: tính theo điểm BSC trung bình năm.
- Trả lương 1 kỳ/tháng. Thực lĩnh giữ nguyên đến đồng, không làm tròn.
- **Phép năm**: 12 ngày/năm + 1 ngày cho mỗi 5 năm thâm niên. Chuyển tối đa 5 ngày sang Q1 năm sau.
- **Tạm ứng**: nhân viên gửi yêu cầu → quản lý/HR duyệt. Tối đa 30% lương cơ bản, 1 lần/tháng.
- **Duyệt nghỉ phép/OT/tạm ứng**: thêm cấp Giám đốc khi vượt ngưỡng (Admin cấu hình). Quá 3 ngày chưa duyệt thì nhắc và báo cấp trên.

## 5. Kỳ lương & vận hành
- Vòng đời kỳ lương như TaskFlow: Nháp → Đã tính → Đã chốt → Đã thanh toán.
- Chỉ Admin mở khóa kỳ đã chốt, bắt buộc nhập lý do, có ghi nhật ký.
- Điều chỉnh thủ công: phép tồn, thưởng khác, trợ cấp, khoản bù, khấu trừ.
- **Kiểm tra tự động trước khi chốt**:
  - Lương thay đổi > 20% so với tháng trước
  - Thực lĩnh âm
  - Thiếu STK/MST
  - Công vượt công chuẩn
  - Trọng số BSC khác 100%
  - Nguồn dữ liệu đã thay đổi sau lần tính gần nhất (lỗi SOURCE_STALE)
- **Xuất file**:
  - Bảng lương Excel
  - Phiếu lương PDF, mẫu đầy đủ và mẫu gọn
  - ZIP toàn bộ phiếu lương
  - Chuyển khoản tạm ứng và cuối kỳ (Excel chung + mẫu riêng của ngân hàng)
  - BHXH, TNCN 12 tháng
- Báo cáo xuất ra Excel và PDF.
- **Phiếu lương**: logo, địa chỉ + MST công ty, chữ ký HR, ghi chú bảo mật, mã QR xác thực (mở trang xác thực phiếu: mã phiếu + kỳ + thực lĩnh ẩn một phần), watermark tên người xem.
  - Công ty: CÔNG TY TNHH Y NHA KHOA 3D — 646J Nguyễn Trãi, Phường Chợ Lớn, TP. Hồ Chí Minh — MST 0304259413.
  - Logo `uploads/logo-1791949307716-8pcl.png`, hiển thị ở phiếu lương, màn hình đăng nhập, sidebar và file xuất ra.
- **Phát hành phiếu lương**: nhân viên chỉ thấy phiếu sau khi HR phát hành. Theo dõi đã xem/đã tải. Thu hồi phải nhập lý do. Gửi email hàng loạt từ hcns@ddd.vn, có ô xác nhận trước khi gửi.
- **Nhân viên tự phục vụ**:
  - Xem phiếu lương và lịch sử lương 12 tháng
  - Gửi khiếu nại phiếu lương: HR xử lý trong 3 ngày, điều chỉnh vào kỳ sau
  - Đổi STK ngân hàng: HR duyệt, có hiệu lực từ kỳ sau
  - Đăng ký người phụ thuộc
- **Backup**: tự động trước khi chốt kỳ + backup thủ công. Khôi phục theo trình tự chạy thử (dry-run) → xác nhận → khôi phục.
- Ẩn số tiền lương trên màn hình cho tới khi bấm xem. STK ngân hàng được mã hóa.
- Mở bảng lương: cho ẩn/hiện cột, ghim cột tên, mật độ gọn.
- Chạy song song với Excel 1 kỳ lương để đối chiếu trước khi dùng thật. Dữ liệu lương bắt đầu từ kỳ hiện tại, không import lương cũ.

## 6. Thông báo, AI, Tổng quan, dữ liệu
- Telegram/Zalo/email: làm sẵn giao diện và cấu trúc, nối backend thật sau.
  - Sự kiện gửi thông báo: giao nhiệm vụ, sắp đến hạn/quá hạn, chờ duyệt nhiệm vụ, mở kỳ OKR/BSC, duyệt nghỉ phép/OT/tạm ứng, phát hành phiếu lương.
- Gemini AI:
  - Gợi ý KR từ Objective
  - Tóm tắt tiến độ dự án
  - Giải thích phiếu lương cho nhân viên
  - Phát hiện bất thường trong bảng lương
  - Chia nhỏ nhiệm vụ
- **Tổng quan** thêm các khối: nhiệm vụ quá hạn, tiến độ dự án, tiến độ OKR/BSC, quỹ lương tháng, việc chờ tôi duyệt.
- **Báo cáo**:
  - Quỹ lương theo phòng ban/tháng
  - Biến động lương 12 tháng
  - Phân bố điểm BSC theo phòng
  - Năng suất: số nhiệm vụ hoàn thành/người
  - Ngân sách dự án kế hoạch so với thực chi
  - Tỷ lệ đúng hạn
- **Nhận việc / nghỉ việc**:
  - Checklist nhận việc bắt buộc có STK, MST, CCCD trước kỳ lương đầu
  - Khi nghỉ việc: thu hồi tài sản, khóa tài khoản đúng ngày nghỉ, quyết toán phép tồn vào lương, bàn giao nhiệm vụ/dự án, chốt sổ BHXH
- **Import Excel** (có file mẫu): nhân viên, hồ sơ lương, chấm công, nhiệm vụ, OKR/KR. Xem trước, báo lỗi từng dòng, chỉ import các dòng hợp lệ.
- **Dữ liệu**: tách lớp lưu dữ liệu riêng, hiện vẫn chạy local, sẵn sàng chuyển sang Supabase. Thao tác offline được (cập nhật nhiệm vụ, xem phiếu lương đã tải, gửi yêu cầu nghỉ phép), đồng bộ khi có mạng.
- Có sẵn dữ liệu mẫu; giữ danh sách nhân viên hiện có trong app.
- Quy mô: 50–200 nhân viên, 10–50 người dùng cùng lúc, 500–3000 nhiệm vụ/tháng. Mục tiêu mở màn hình bất kỳ dưới 1 giây.
- Định dạng: số tiền 1.234.567 · ngày dd/mm/yyyy. Không làm chế độ tối. Nhân viên dùng được trên điện thoại cho Kanban, phiếu lương và chấm công.
- Màn hình trống có hướng dẫn bước tiếp theo. Mọi thao tác xóa/chốt/phát hành đều có hộp xác nhận.
