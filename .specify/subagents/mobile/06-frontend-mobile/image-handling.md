---
name: Mobile Image Handling
platform: mobile
description: Image loading, caching, optimization, placeholders, and memory management for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Image Handling

## Purpose

Implement efficient image loading systems that handle network images, local assets, caching strategies, memory management, placeholder states, and image transformations. The image layer should optimize for performance, reduce bandwidth usage, and provide excellent visual feedback during loading.

## Image Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Image Pipeline                              │
├─────────────────────────────────────────────────────────────────┤
│  Source              │  Processing         │  Display           │
│  - Network URL       │  - Decode           │  - Placeholder     │
│  - Local file        │  - Resize           │  - Fade-in         │
│  - Base64            │  - Transform        │  - Error state     │
│  - Asset bundle      │  - Cache            │  - Retry           │
├─────────────────────────────────────────────────────────────────┤
│                      Cache Layers                                │
│  Memory Cache → Disk Cache → Network                            │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Image Handling

### Kingfisher Setup

```swift
// ImageLoader.swift
import Kingfisher
import SwiftUI

// Configure Kingfisher globally
struct ImageLoaderConfiguration {
    static func configure() {
        // Memory cache
        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        ImageCache.default.memoryStorage.config.countLimit = 100

        // Disk cache
        ImageCache.default.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500 MB
        ImageCache.default.diskStorage.config.expiration = .days(7)

        // Downloader
        ImageDownloader.default.downloadTimeout = 30
    }

    static func clearCache() async {
        await ImageCache.default.clearMemoryCache()
        try? await ImageCache.default.clearDiskCache()
    }

    static func cacheSize() async -> UInt {
        return await withCheckedContinuation { continuation in
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case .success(let size):
                    continuation.resume(returning: size)
                case .failure:
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}

// AsyncImage with Kingfisher
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        KFImage(url)
            .placeholder { placeholder() }
            .fade(duration: 0.25)
            .onSuccess { result in
                phase = .success(Image(uiImage: result.image))
            }
            .onFailure { error in
                phase = .failure(error)
            }
            .resizable()
    }
}

// ProductImage.swift
struct ProductImage: View {
    let url: URL?
    let size: CGSize
    let contentMode: SwiftUI.ContentMode

    init(url: URL?, size: CGSize = CGSize(width: 200, height: 200), contentMode: SwiftUI.ContentMode = .fill) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
    }

    var body: some View {
        KFImage(url)
            .placeholder {
                ShimmerView()
            }
            .setProcessor(
                DownsamplingImageProcessor(size: size) |>
                RoundCornerImageProcessor(cornerRadius: 8)
            )
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .retry(maxCount: 3, interval: .seconds(2))
            .onFailure { _ in }
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// AvatarImage.swift
struct AvatarImage: View {
    let url: URL?
    let size: CGFloat
    let fallbackInitials: String?

    init(url: URL?, size: CGFloat = 40, fallbackInitials: String? = nil) {
        self.url = url
        self.size = size
        self.fallbackInitials = fallbackInitials
    }

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .placeholder {
                        avatarPlaceholder
                    }
                    .setProcessor(
                        DownsamplingImageProcessor(size: CGSize(width: size * 2, height: size * 2)) |>
                        RoundCornerImageProcessor(cornerRadius: size / 2)
                    )
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))

            if let initials = fallbackInitials {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// ImageGallery.swift
struct ImageGallery: View {
    let images: [URL]
    @State private var selectedIndex: Int = 0
    @State private var showFullScreen: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Main image
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                    KFImage(url)
                        .placeholder {
                            ShimmerView()
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                        .onTapGesture {
                            showFullScreen = true
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 300)

            // Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        KFImage(url)
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 120, height: 120)))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(selectedIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                withAnimation { selectedIndex = index }
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageViewer(images: images, initialIndex: selectedIndex)
        }
    }
}

// Shimmer placeholder
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.5),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = UIScreen.main.bounds.width
                }
            }
    }
}
```

### Native Image Processing

```swift
// ImageProcessor.swift
import UIKit

enum ImageProcessor {
    static func resize(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func compress(_ image: UIImage, quality: CGFloat = 0.8) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }

    static func thumbnail(from url: URL, maxSize: CGFloat) async throws -> UIImage {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageError.thumbnailCreationFailed
        }

        return UIImage(cgImage: cgImage)
    }

    static func applyBlur(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)

        guard let outputImage = filter?.outputImage else { return nil }

        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    enum ImageError: Error {
        case thumbnailCreationFailed
    }
}

// ImagePicker.swift
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: ((UIImage) -> Void)?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self?.parent.selectedImage = image
                        self?.parent.onImageSelected?(image)
                    }
                }
            }
        }
    }
}
```

## Android Image Handling

### Coil Setup

```kotlin
// ImageLoaderModule.kt
@Module
@InstallIn(SingletonComponent::class)
object ImageLoaderModule {

    @Provides
    @Singleton
    fun provideImageLoader(
        @ApplicationContext context: Context
    ): ImageLoader {
        return ImageLoader.Builder(context)
            .memoryCache {
                MemoryCache.Builder(context)
                    .maxSizePercent(0.25) // 25% of available memory
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(context.cacheDir.resolve("image_cache"))
                    .maxSizeBytes(500 * 1024 * 1024) // 500 MB
                    .build()
            }
            .crossfade(true)
            .crossfade(300)
            .respectCacheHeaders(false)
            .components {
                add(SvgDecoder.Factory())
                add(GifDecoder.Factory())
            }
            .logger(if (BuildConfig.DEBUG) DebugLogger() else null)
            .build()
    }
}

// CachedImage.kt
@Composable
fun CachedImage(
    url: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    placeholder: @Composable (() -> Unit)? = null,
    error: @Composable (() -> Unit)? = null,
    transformations: List<Transformation> = emptyList()
) {
    SubcomposeAsyncImage(
        model = ImageRequest.Builder(LocalContext.current)
            .data(url)
            .crossfade(true)
            .transformations(transformations)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .diskCachePolicy(CachePolicy.ENABLED)
            .build(),
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        loading = {
            placeholder?.invoke() ?: ShimmerPlaceholder(modifier = Modifier.matchParentSize())
        },
        error = {
            error?.invoke() ?: ImageErrorPlaceholder(modifier = Modifier.matchParentSize())
        }
    )
}

// ProductImage.kt
@Composable
fun ProductImage(
    url: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    cornerRadius: Dp = 8.dp
) {
    CachedImage(
        url = url,
        contentDescription = "Product image",
        modifier = modifier.clip(RoundedCornerShape(cornerRadius)),
        contentScale = contentScale,
        transformations = listOf(
            RoundedCornersTransformation(cornerRadius.value)
        )
    )
}

// AvatarImage.kt
@Composable
fun AvatarImage(
    url: String?,
    size: Dp = 40.dp,
    fallbackInitials: String? = null,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape),
        contentAlignment = Alignment.Center
    ) {
        if (url != null) {
            SubcomposeAsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(url)
                    .crossfade(true)
                    .transformations(CircleCropTransformation())
                    .size(Size((size * 2).value.toInt(), (size * 2).value.toInt()))
                    .build(),
                contentDescription = "Avatar",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                loading = {
                    AvatarPlaceholder(size = size, initials = fallbackInitials)
                },
                error = {
                    AvatarPlaceholder(size = size, initials = fallbackInitials)
                }
            )
        } else {
            AvatarPlaceholder(size = size, initials = fallbackInitials)
        }
    }
}

@Composable
private fun AvatarPlaceholder(
    size: Dp,
    initials: String?,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(size)
            .background(
                color = MaterialTheme.colorScheme.primaryContainer,
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (initials != null) {
            Text(
                text = initials,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontSize = (size.value * 0.4).sp
                ),
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
        } else {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                modifier = Modifier.size(size * 0.5f),
                tint = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
    }
}

// ShimmerPlaceholder.kt
@Composable
fun ShimmerPlaceholder(
    modifier: Modifier = Modifier
) {
    val shimmerColors = listOf(
        Color.LightGray.copy(alpha = 0.6f),
        Color.LightGray.copy(alpha = 0.2f),
        Color.LightGray.copy(alpha = 0.6f)
    )

    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnimation = transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = 1200,
                easing = FastOutSlowInEasing
            )
        ),
        label = "shimmer"
    )

    val brush = Brush.linearGradient(
        colors = shimmerColors,
        start = Offset(translateAnimation.value - 200f, 0f),
        end = Offset(translateAnimation.value, 0f)
    )

    Box(
        modifier = modifier.background(brush)
    )
}

// ImageGallery.kt
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ImageGallery(
    images: List<String>,
    modifier: Modifier = Modifier,
    onImageClick: (Int) -> Unit = {}
) {
    var selectedIndex by remember { mutableIntStateOf(0) }
    val pagerState = rememberPagerState(pageCount = { images.size })

    LaunchedEffect(pagerState.currentPage) {
        selectedIndex = pagerState.currentPage
    }

    Column(modifier = modifier) {
        // Main pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(300.dp)
        ) { page ->
            CachedImage(
                url = images[page],
                contentDescription = "Image ${page + 1}",
                modifier = Modifier
                    .fillMaxSize()
                    .clickable { onImageClick(page) },
                contentScale = ContentScale.Fit
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Thumbnails
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 16.dp)
        ) {
            itemsIndexed(images) { index, url ->
                CachedImage(
                    url = url,
                    contentDescription = "Thumbnail ${index + 1}",
                    modifier = Modifier
                        .size(60.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .border(
                            width = 2.dp,
                            color = if (selectedIndex == index)
                                MaterialTheme.colorScheme.primary
                            else
                                Color.Transparent,
                            shape = RoundedCornerShape(4.dp)
                        )
                        .clickable {
                            selectedIndex = index
                        },
                    contentScale = ContentScale.Crop
                )
            }
        }

        // Page indicator
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            repeat(images.size) { index ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .padding(2.dp)
                        .clip(CircleShape)
                        .background(
                            if (index == selectedIndex)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                        )
                )
            }
        }
    }
}
```

### Image Picker and Compression

```kotlin
// ImagePickerLauncher.kt
@Composable
fun rememberImagePickerLauncher(
    onImagePicked: (Uri) -> Unit
): ManagedActivityResultLauncher<PickVisualMediaRequest, Uri?> {
    return rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let { onImagePicked(it) }
    }
}

@Composable
fun rememberMultipleImagePickerLauncher(
    maxItems: Int = 10,
    onImagesPicked: (List<Uri>) -> Unit
): ManagedActivityResultLauncher<PickVisualMediaRequest, List<Uri>> {
    return rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems)
    ) { uris ->
        if (uris.isNotEmpty()) {
            onImagesPicked(uris)
        }
    }
}

// ImageCompressor.kt
class ImageCompressor @Inject constructor(
    @ApplicationContext private val context: Context
) {
    suspend fun compress(
        uri: Uri,
        maxWidth: Int = 1920,
        maxHeight: Int = 1080,
        quality: Int = 80
    ): File = withContext(Dispatchers.IO) {
        val inputStream = context.contentResolver.openInputStream(uri)
            ?: throw IllegalArgumentException("Cannot open URI")

        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }

        // Get dimensions
        BitmapFactory.decodeStream(inputStream, null, options)
        inputStream.close()

        // Calculate sample size
        options.inSampleSize = calculateInSampleSize(options, maxWidth, maxHeight)
        options.inJustDecodeBounds = false

        // Decode bitmap
        val newInputStream = context.contentResolver.openInputStream(uri)!!
        val bitmap = BitmapFactory.decodeStream(newInputStream, null, options)!!
        newInputStream.close()

        // Resize if needed
        val resizedBitmap = resizeBitmap(bitmap, maxWidth, maxHeight)

        // Save compressed
        val outputFile = File(context.cacheDir, "compressed_${System.currentTimeMillis()}.jpg")
        FileOutputStream(outputFile).use { out ->
            resizedBitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        }

        if (resizedBitmap != bitmap) {
            bitmap.recycle()
        }
        resizedBitmap.recycle()

        outputFile
    }

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val (height, width) = options.outHeight to options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2

            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }

        return inSampleSize
    }

    private fun resizeBitmap(bitmap: Bitmap, maxWidth: Int, maxHeight: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        if (width <= maxWidth && height <= maxHeight) {
            return bitmap
        }

        val ratio = minOf(maxWidth.toFloat() / width, maxHeight.toFloat() / height)
        val newWidth = (width * ratio).toInt()
        val newHeight = (height * ratio).toInt()

        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }
}
```

## React Native Image Handling

### FastImage Setup

```typescript
// components/CachedImage.tsx
import React, { useState } from 'react';
import { View, StyleSheet, ViewStyle } from 'react-native';
import FastImage, { FastImageProps, Priority } from 'react-native-fast-image';
import { ShimmerPlaceholder } from './ShimmerPlaceholder';

interface CachedImageProps extends Omit<FastImageProps, 'source'> {
  url?: string | null;
  fallback?: React.ReactNode;
  showPlaceholder?: boolean;
  containerStyle?: ViewStyle;
  priority?: Priority;
}

export const CachedImage: React.FC<CachedImageProps> = ({
  url,
  fallback,
  showPlaceholder = true,
  containerStyle,
  priority = FastImage.priority.normal,
  style,
  ...props
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  if (!url || hasError) {
    return fallback ? <>{fallback}</> : null;
  }

  return (
    <View style={containerStyle}>
      {isLoading && showPlaceholder && (
        <ShimmerPlaceholder style={[StyleSheet.absoluteFill, style]} />
      )}
      <FastImage
        source={{
          uri: url,
          priority,
          cache: FastImage.cacheControl.immutable,
        }}
        style={style}
        onLoadStart={() => setIsLoading(true)}
        onLoad={() => setIsLoading(false)}
        onError={() => {
          setIsLoading(false);
          setHasError(true);
        }}
        {...props}
      />
    </View>
  );
};

// components/ProductImage.tsx
import React from 'react';
import { StyleSheet, View, ViewStyle } from 'react-native';
import FastImage from 'react-native-fast-image';
import { CachedImage } from './CachedImage';
import { tokens } from '../design/theme';

interface ProductImageProps {
  url?: string | null;
  size?: number | { width: number; height: number };
  borderRadius?: number;
  style?: ViewStyle;
}

export const ProductImage: React.FC<ProductImageProps> = ({
  url,
  size = 200,
  borderRadius = 8,
  style,
}) => {
  const dimensions =
    typeof size === 'number' ? { width: size, height: size } : size;

  return (
    <CachedImage
      url={url}
      style={[
        {
          ...dimensions,
          borderRadius,
        },
        style,
      ]}
      resizeMode={FastImage.resizeMode.cover}
      fallback={
        <View
          style={[
            styles.placeholder,
            { ...dimensions, borderRadius },
            style,
          ]}
        />
      }
    />
  );
};

const styles = StyleSheet.create({
  placeholder: {
    backgroundColor: tokens.colors.neutral[200],
  },
});

// components/AvatarImage.tsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import FastImage from 'react-native-fast-image';
import { CachedImage } from './CachedImage';
import { tokens } from '../design/theme';

interface AvatarImageProps {
  url?: string | null;
  size?: number;
  fallbackInitials?: string;
}

export const AvatarImage: React.FC<AvatarImageProps> = ({
  url,
  size = 40,
  fallbackInitials,
}) => {
  const AvatarPlaceholder = () => (
    <View
      style={[
        styles.placeholder,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
        },
      ]}
    >
      {fallbackInitials ? (
        <Text style={[styles.initials, { fontSize: size * 0.4 }]}>
          {fallbackInitials}
        </Text>
      ) : (
        <Icon name="person" size={size * 0.5} color={tokens.colors.primary[500]} />
      )}
    </View>
  );

  return (
    <CachedImage
      url={url}
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
      }}
      resizeMode={FastImage.resizeMode.cover}
      fallback={<AvatarPlaceholder />}
      priority={FastImage.priority.high}
    />
  );
};

const styles = StyleSheet.create({
  placeholder: {
    backgroundColor: tokens.colors.primary[100],
    alignItems: 'center',
    justifyContent: 'center',
  },
  initials: {
    fontWeight: '600',
    color: tokens.colors.primary[700],
  },
});

// components/ImageGallery.tsx
import React, { useState, useRef } from 'react';
import {
  View,
  FlatList,
  Dimensions,
  TouchableOpacity,
  StyleSheet,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import FastImage from 'react-native-fast-image';
import { CachedImage } from './CachedImage';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface ImageGalleryProps {
  images: string[];
  onImagePress?: (index: number) => void;
}

export const ImageGallery: React.FC<ImageGalleryProps> = ({
  images,
  onImagePress,
}) => {
  const [selectedIndex, setSelectedIndex] = useState(0);
  const flatListRef = useRef<FlatList>(null);

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const index = Math.round(
      event.nativeEvent.contentOffset.x / SCREEN_WIDTH
    );
    setSelectedIndex(index);
  };

  const handleThumbnailPress = (index: number) => {
    setSelectedIndex(index);
    flatListRef.current?.scrollToIndex({ index, animated: true });
  };

  return (
    <View>
      {/* Main image carousel */}
      <FlatList
        ref={flatListRef}
        data={images}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={handleScroll}
        scrollEventThrottle={16}
        renderItem={({ item, index }) => (
          <TouchableOpacity
            activeOpacity={0.9}
            onPress={() => onImagePress?.(index)}
          >
            <CachedImage
              url={item}
              style={styles.mainImage}
              resizeMode={FastImage.resizeMode.contain}
            />
          </TouchableOpacity>
        )}
        keyExtractor={(item, index) => `main-${index}`}
      />

      {/* Thumbnails */}
      <FlatList
        data={images}
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.thumbnailContainer}
        renderItem={({ item, index }) => (
          <TouchableOpacity
            onPress={() => handleThumbnailPress(index)}
            style={[
              styles.thumbnail,
              selectedIndex === index && styles.thumbnailSelected,
            ]}
          >
            <CachedImage
              url={item}
              style={styles.thumbnailImage}
              resizeMode={FastImage.resizeMode.cover}
            />
          </TouchableOpacity>
        )}
        keyExtractor={(item, index) => `thumb-${index}`}
      />

      {/* Page indicator */}
      <View style={styles.indicatorContainer}>
        {images.map((_, index) => (
          <View
            key={index}
            style={[
              styles.indicator,
              selectedIndex === index && styles.indicatorActive,
            ]}
          />
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  mainImage: {
    width: SCREEN_WIDTH,
    height: 300,
  },
  thumbnailContainer: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 8,
  },
  thumbnail: {
    borderRadius: 4,
    overflow: 'hidden',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  thumbnailSelected: {
    borderColor: tokens.colors.primary[500],
  },
  thumbnailImage: {
    width: 60,
    height: 60,
  },
  indicatorContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingVertical: 8,
    gap: 4,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: tokens.colors.neutral[300],
  },
  indicatorActive: {
    backgroundColor: tokens.colors.primary[500],
  },
});
```

### Image Compression

```typescript
// utils/imageUtils.ts
import { Image } from 'react-native-compressor';
import RNFS from 'react-native-fs';

export const compressImage = async (
  uri: string,
  options?: {
    maxWidth?: number;
    maxHeight?: number;
    quality?: number;
  }
): Promise<string> => {
  const { maxWidth = 1920, maxHeight = 1080, quality = 0.8 } = options ?? {};

  const result = await Image.compress(uri, {
    maxWidth,
    maxHeight,
    quality,
    input: 'uri',
    output: 'jpg',
    returnableOutputType: 'uri',
  });

  return result;
};

export const getImageSize = async (
  uri: string
): Promise<{ width: number; height: number }> => {
  return new Promise((resolve, reject) => {
    Image.getSize(
      uri,
      (width, height) => resolve({ width, height }),
      reject
    );
  });
};

export const clearImageCache = async (): Promise<void> => {
  await FastImage.clearMemoryCache();
  await FastImage.clearDiskCache();
};

export const prefetchImages = (urls: string[]): void => {
  const sources = urls.map((uri) => ({ uri }));
  FastImage.preload(sources);
};
```

## Flutter Image Handling

### Cached Network Image

```dart
// widgets/cached_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppCachedImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return ShimmerWidget(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
    );
  }
}

// widgets/product_image.dart
class ProductImage extends StatelessWidget {
  final String? url;
  final double size;
  final double borderRadius;

  const ProductImage({
    super.key,
    this.url,
    this.size = 200,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AppCachedImage(
      imageUrl: url,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}

// widgets/avatar_image.dart
class AvatarImage extends StatelessWidget {
  final String? url;
  final double size;
  final String? fallbackInitials;

  const AvatarImage({
    super.key,
    this.url,
    this.size = 40,
    this.fallbackInitials,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _buildPlaceholder(context);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
        memCacheWidth: (size * 2).toInt(),
        memCacheHeight: (size * 2).toInt(),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: fallbackInitials != null
            ? Text(
                fallbackInitials!,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.5,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
      ),
    );
  }
}

// widgets/shimmer_widget.dart
class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## Cache Management

```typescript
// React Native cache utilities
export const ImageCacheManager = {
  async getCacheSize(): Promise<number> {
    // Implementation depends on library
    return 0;
  },

  async clearCache(): Promise<void> {
    await FastImage.clearMemoryCache();
    await FastImage.clearDiskCache();
  },

  preloadImages(urls: string[]): void {
    FastImage.preload(urls.map((uri) => ({ uri })));
  },
};
```

## Output Expectations

When implementing image handling, the subagent should:

1. Configure memory and disk caching appropriately
2. Implement placeholder and error states
3. Support image transformations (resize, crop, blur)
4. Handle image compression for uploads
5. Implement progressive loading
6. Support image galleries with zoom
7. Configure proper cache invalidation
8. Handle different image sources (URL, local, base64)
9. Implement lazy loading for lists
10. Prefetch images for better UX
