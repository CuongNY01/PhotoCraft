# PhotoCraft - Ứng Dụng Biên Tập & Nâng Cao Chất Lượng Ảnh Trên Di Động

PhotoCraft là giải pháp ứng dụng di động hoàn chỉnh cho việc biên tập, nâng cao chất lượng hình ảnh, áp dụng bộ lọc màu và làm nét chi tiết ảnh, được xây dựng theo đúng phác thảo giao diện trong tệp **`Photocraft (1).pdf`**.

---

## 🌟 Tính Năng Đáp Ứng Đầy Đủ 8 Yêu Cầu Chức Năng

| STT | Yêu cầu chức năng | Chi tiết triển khai kỹ thuật |
|---|---|---|
| **1** | **Chọn ảnh (Camera / Thư viện / Mẫu)** | Cho phép chụp ảnh mới qua Camera, chọn ảnh từ thư viện thiết bị (`image_picker`), hoặc chọn nhanh các ảnh mẫu phong cảnh/chân dung/phố đêm có sẵn (`assets/samples`). |
| **2** | **Cắt / Xoay / Lật ảnh** | Cắt theo tỷ lệ tiêu chuẩn (**Tự do, 1:1 vuông, 4:3, 16:9**), xoay góc 90° trái/phải, lật ngang, lật dọc, hỗ trợ lưới tỷ lệ một phần ba (**Rule of Thirds**). |
| **3** | **Bộ lọc màu (Filter)** | Gửi yêu cầu HTTP kèm dữ liệu nhị phân ảnh qua **Python API (FastAPI + OpenCV / PIL)**, hỗ trợ đa dạng bộ lọc: **Gốc, Trắng đen (Grayscale), Sepia, vivi HDR (LAB CLAHE + HSV Saturation Boost), Màu 1 (Vintage Retro Film có viền mờ), Màu 2 (Cool Cold Blue), Tranh chì (Pencil), Chạm nổi (Emboss), Âm bản (Invert)** kèm thanh trượt điều chỉnh cường độ (0% - 100%). |
| **4** | **Tối ưu / Làm nét ảnh** | Gửi ảnh qua Python API xử lý bằng các thuật toán xử lý ảnh số hàng đầu bằng OpenCV: <br>• **Kernel 3x3**: Bộ lọc tích chập không gian Laplacian<br>• **Unsharp Masking (USM)**: Tách biên tần số cao bằng Gaussian Mask rồi cộng tăng cường biên độ<br>• **High-Boost Filtering**: Khuếch đại thành phần tần số cao làm rõ ảnh mờ<br>• **CLAHE Contrast**: Cân bằng biểu đồ độ sáng cục bộ thích ứng trên kênh L không gian LAB |
| **5** | **Lưu về máy & Chia sẻ** | Lưu ảnh chất lượng cao vào bộ nhớ thiết bị (`path_provider`), xuất file và mở hộp thoại chia sẻ hệ thống (`share_plus`) tới mạng xã hội và các ứng dụng khác. |
| **6** | **Lịch sử chỉnh sửa (SQLite)** | Tự động lưu vết toàn bộ ảnh đã biên tập vào CSDL **SQLite** (`sqflite`), lưu thông tin tên ảnh, đường dẫn tệp, bộ lọc và thuật toán làm nét đã dùng, thời gian chỉnh sửa, hỗ trợ tìm kiếm nhanh và xóa bản ghi. |
| **7** | **Bộ sưu tập yêu thích** | Nút tim (♥) cho phép đánh dấu ảnh tâm đắc. Màn hình "Yêu thích" hiển thị dạng lưới 2 cột đẹp mắt giúp quản lý và mở xem/biên tập lại riêng biệt. |
| **8** | **Nhật ký ảnh** | Hỗ trợ người dùng lưu cảm nghĩ, đánh giá sao (**1 - 5 sao ★★★★★**) và ghi chú cá nhân đi kèm với từng bức ảnh vào CSDL SQLite. Cho phép xem lại và sửa nhật ký bất cứ lúc nào. |

---

## 🏗️ Kiến Trúc Hệ Thống

```
PhotoCraft/
├── backend/                         # Backend Python API (Xử lý ảnh số)
│   ├── main.py                      # FastAPI server (Endpoints: /api/filter, /api/sharpen, /api/health)
│   ├── filters.py                   # Biến đổi không gian màu, ma trận lọc màu (OpenCV & PIL)
│   ├── sharpen.py                   # Tích chập không gian, Kernel 3x3, USM, High-Boost, CLAHE
│   └── requirements.txt             # Thư viện: fastapi, uvicorn, opencv-python, pillow, numpy
│
├── mobile_app/                      # Ứng dụng Di động (Flutter Dart)
│   ├── lib/
│   │   ├── main.dart                # Entry point & Thanh điều hướng 5 tab (Trang chủ, Biên tập, Lịch sử, Yêu thích, Cài đặt)
│   │   ├── database/
│   │   │   └── db_helper.dart       # Quản trị SQLite DB (bảng photos)
│   │   ├── models/
│   │   │   └── photo_record.dart    # Data Model (id, title, paths, filters, note, rating, favorite)
│   │   ├── services/
│   │   │   ├── api_service.dart     # HTTP Client kết nối tới Python Backend (Multipart Form)
│   │   │   └── image_processor.dart # Cắt, xoay, lật, fallback xử lý offline
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Giao diện Dark Luxury tone chuẩn phác thảo PDF
│   │   ├── screens/
│   │   │   ├── home_screen.dart     # Trang chủ (3 thẻ thao tác, thống kê, chỉnh sửa gần đây)
│   │   │   ├── editor_screen.dart   # Màn hình Biên tập (Cắt/Xoay/Lật, Bộ lọc màu, Làm nét)
│   │   │   ├── history_screen.dart  # Lịch sử & Nhật ký ảnh (Tìm kiếm, sửa nhật ký, sửa tiếp)
│   │   │   ├── favorites_screen.dart# Bộ sưu tập yêu thích (Lưới 2 cột)
│   │   │   └── settings_screen.dart # Cài đặt kết nối IP Python Backend & Reset dữ liệu
│   │   └── widgets/
│   │       └── save_diary_sheet.dart# Bottom Sheet Lưu trữ & Đánh giá sao, viết nhật ký, chia sẻ
│   ├── assets/samples/              # Ảnh mẫu có sẵn (Sunset, Portrait, Night City)
│   └── build/app/outputs/flutter-apk/app-debug.apk # File APK Android đã đóng gói sẵn sàng
│
├── start_backend.bat                # Kịch bản khởi chạy nhanh Backend Python
├── run_android.bat                  # Kịch bản chạy App Android
└── run_web.bat                      # Kịch bản chạy App xem trước trên trình duyệt Chrome
```

---

## 🚀 Hướng Dẫn Khởi Chạy

### 1. Khởi động Backend Python API
Mở cửa sổ dòng lệnh tại thư mục gốc và chạy:
```bash
.\start_backend.bat
```
Hoặc chạy lệnh trực tiếp:
```bash
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```
- API sẽ lắng nghe tại: `http://localhost:8000` (hoặc `http://10.0.2.2:8000` khi chạy máy ảo Android).
- Tài liệu tương tác Swagger UI: `http://localhost:8000/docs`.

### 2. Cài đặt & Chạy Ứng dụng Di động
- **Cài đặt APK trực tiếp lên máy ảo hoặc điện thoại Android thật**:
  File APK đã được build tại:
  ```
  mobile_app/build/app/outputs/flutter-apk/app-debug.apk
  ```
  Cài qua adb:
  ```bash
  adb install -r mobile_app/build/app/outputs/flutter-apk/app-debug.apk
  ```
- **Chạy trực tiếp từ mã nguồn Flutter**:
  ```bash
  .\run_android.bat
  ```
- **Xem trước trực quan ngay trên trình duyệt Chrome**:
  ```bash
  .\run_web.bat
  ```

---

## 🔬 Chi Tiết Thuật Toán Xử Lý Ảnh Số Trên Backend (OpenCV)

1. **Sepia Tone Matrix**:
   Biến đổi không gian màu RGB bằng phép nhân ma trận trọng số chuyên biệt:
   $$\begin{bmatrix} R' \\ G' \\ B' \end{bmatrix} = \begin{bmatrix} 0.393 & 0.769 & 0.189 \\ 0.349 & 0.686 & 0.168 \\ 0.272 & 0.534 & 0.131 \end{bmatrix} \begin{bmatrix} R \\ G \\ B \end{bmatrix}$$
2. **vivi HDR**:
   Chuyển ảnh sang không gian màu **LAB**, áp dụng thuật toán cân bằng biểu đồ độ sáng thích ứng (**CLAHE**) trên kênh $L$, sau đó chuyển sang không gian màu **HSV** để tăng cường độ bão hòa màu $S$ và giữ nguyên sắc độ tự nhiên.
3. **Bộ lọc làm nét Tích chập (Kernel 3x3 Sharpening)**:
   Sử dụng ma trận nhân tích chập không gian 2D với trọng số cạnh trung tâm:
   $$K = \begin{bmatrix} 0 & -w & 0 \\ -w & 1 + 4w & -w \\ 0 & -w & 0 \end{bmatrix}$$
4. **Unsharp Masking (USM)**:
   Tách thành phần làm mờ tần số thấp bằng Gaussian Filter $G_\sigma$:
   $$I_{\text{sharp}} = I_{\text{original}} + \alpha \times (I_{\text{original}} - G_\sigma * I_{\text{original}})$$
   Tối ưu hóa tốc độ tính toán qua hàm OpenCV `cv2.addWeighted`.
