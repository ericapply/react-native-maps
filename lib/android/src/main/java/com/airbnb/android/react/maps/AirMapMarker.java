package com.airbnb.android.react.maps;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.net.Uri;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;

import com.facebook.common.executors.CallerThreadExecutor;
import com.facebook.common.references.CloseableReference;
import com.facebook.datasource.DataSource;
import com.facebook.drawee.backends.pipeline.Fresco;
import com.facebook.drawee.drawable.ScalingUtils;
import com.facebook.drawee.generic.GenericDraweeHierarchy;
import com.facebook.drawee.generic.GenericDraweeHierarchyBuilder;
import com.facebook.drawee.view.DraweeHolder;
import com.facebook.imagepipeline.core.ImagePipeline;
import com.facebook.imagepipeline.datasource.BaseBitmapDataSubscriber;
import com.facebook.imagepipeline.image.CloseableImage;
import com.facebook.imagepipeline.request.ImageRequest;
import com.facebook.imagepipeline.request.ImageRequestBuilder;
import com.facebook.react.bridge.ReadableMap;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.BitmapDescriptor;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.maps.android.clustering.ClusterItem;
import com.google.maps.android.clustering.ClusterManager;

import java.util.HashSet;

import javax.annotation.Nullable;

public class AirMapMarker extends AirMapFeature implements ClusterItem {

    private static final String TAG = AirMapMarker.class.getName();

    private ClusterManager<AirMapMarker> mClusterManager;

    private MarkerOptions markerOptions;
    private Marker marker;
    private int width;
    private int height;
    private String identifier;

    private LatLng position;
    private String title;
    private String snippet;

    private boolean anchorIsSet;
    private float anchorX;
    private float anchorY;

    private AirMapCallout calloutView;
    private View wrappedCalloutView;
    private final Context context;

    private float markerHue = 0.0f; // should be between 0 and 360
    private BitmapDescriptor iconBitmapDescriptor;
    private Bitmap iconBitmap;

    private float rotation = 0.0f;
    private boolean flat = false;
    private boolean draggable = false;
    private boolean cluster = false;
    private int zIndex = 0;
    private float opacity = 1.0f;

    private float calloutAnchorX;
    private float calloutAnchorY;
    private boolean calloutAnchorIsSet;

    private boolean hasCustomMarkerView = false;

    private final DraweeHolder<?> logoHolder;

    private static HashSet<String> isCacheAdded = new HashSet<>();

    public AirMapMarker(Context context) {
        super(context);
        this.context = context;
        logoHolder = DraweeHolder.create(createDraweeHierarchy(), context);
        logoHolder.onAttach();
    }

    private GenericDraweeHierarchy createDraweeHierarchy() {
        return new GenericDraweeHierarchyBuilder(getResources())
                .setActualImageScaleType(ScalingUtils.ScaleType.FIT_CENTER)
                .setFadeDuration(0)
                .build();
    }

    public void setCoordinate(ReadableMap coordinate) {
        position = new LatLng(coordinate.getDouble("latitude"), coordinate.getDouble("longitude"));
        if (marker != null) {
            marker.setPosition(position);
        }
        update();
    }

    public void setIdentifier(String identifier) {
        this.identifier = identifier;
        update();
    }

    public String getIdentifier() {
        return this.identifier;
    }

    public void setTitle(String title) {
        this.title = title;
        if (marker != null) {
            marker.setTitle(title);
        }
        update();
    }

    public void setSnippet(String snippet) {
        this.snippet = snippet;
        if (marker != null) {
            marker.setSnippet(snippet);
        }
        update();
    }

    public void setRotation(float rotation) {
        this.rotation = rotation;
        if (marker != null) {
            marker.setRotation(rotation);
        }
        update();
    }

    public void setFlat(boolean flat) {
        this.flat = flat;
        if (marker != null) {
            marker.setFlat(flat);
        }
        update();
    }

    public void setDraggable(boolean draggable) {
        this.draggable = draggable;
        if (marker != null) {
            marker.setDraggable(draggable);
        }
        update();
    }

    public void setCluster(boolean cluster) {
        this.cluster = cluster;
        update();
    }

    public boolean getCluster() {
        return this.cluster;
    }

    public void setZIndex(int zIndex) {
        this.zIndex = zIndex;
        if (marker != null) {
            marker.setZIndex(zIndex);
        }
        update();
    }

    public void setOpacity(float opacity) {
        this.opacity = opacity;
        if (marker != null) {
            marker.setAlpha(opacity);
        }
        update();
    }

    public void setMarkerHue(float markerHue) {
        this.markerHue = markerHue;
        update();
    }

    public void setAnchor(double x, double y) {
        anchorIsSet = true;
        anchorX = (float) x;
        anchorY = (float) y;
        if (marker != null) {
            marker.setAnchor(anchorX, anchorY);
        }
        update();
    }

    public void setCalloutAnchor(double x, double y) {
        calloutAnchorIsSet = true;
        calloutAnchorX = (float) x;
        calloutAnchorY = (float) y;
        if (marker != null) {
            marker.setInfoWindowAnchor(calloutAnchorX, calloutAnchorY);
        }
        update();
    }

    public void setImage(final String uri) {
        if (uri == null) {
            // Render default marker
            iconBitmapDescriptor = null;
            iconBitmap = null;
            update();
            return;
        }

        try {
            while(isCacheAdded.contains(uri))
                Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        BitmapDescriptorContainer bitmapDescriptorContainer = LruCacheManager.getInstance().getBitmapFromMemCache(uri);
        if(bitmapDescriptorContainer!=null) {
            // Render icon from cached bitmap
            iconBitmapDescriptor = bitmapDescriptorContainer.mBitmapDescriptor;
            iconBitmap = bitmapDescriptorContainer.mBitmap;
            update();

            Log.v(TAG, "Reusing Bitmap " + uri);
            return;
        }

        Log.v(TAG, "Start Loading Bitmap from uri: " + uri);

        // In Debug, uri will be http || https, use Fresco to load the Image
        // In Release, uri will be image name

        if (uri.startsWith("http://") || uri.startsWith("https://") || uri.startsWith("file://")) {

            // Load Bitmap from uri using Fresco
            ImageRequest imageRequest = ImageRequestBuilder
                    .newBuilderWithSource(Uri.parse(uri))
                    .setAutoRotateEnabled(true)
                    .build();

            ImagePipeline imagePipeline = Fresco.getImagePipeline();
            final DataSource<CloseableReference<CloseableImage>>
                    dataSource = imagePipeline.fetchDecodedImage(imageRequest, this);
            isCacheAdded.add(uri);
            dataSource.subscribe(new BaseBitmapDataSubscriber() {

                @Override
                public void onNewResultImpl(@Nullable Bitmap bitmap) {
                    if (dataSource.isFinished() && bitmap != null) {
                        Log.v(TAG, "Finished Loading Bitmap from uri: " + uri);
                        iconBitmapDescriptor = LruCacheManager.getInstance().addBitmapToMemoryCache(uri, bitmap);
                        iconBitmap = bitmap;
                        dataSource.close();
                        update();
                        isCacheAdded.remove(uri);
                    }
                }

                @Override
                public void onFailureImpl(DataSource dataSource) {
                    if (dataSource != null) {
                        dataSource.close();
                    }
                    isCacheAdded.remove(uri);
                }
            }, CallerThreadExecutor.getInstance());
        } else {
            Bitmap bitmap = getBitmapByDrawableName(uri);
            iconBitmapDescriptor = LruCacheManager.getInstance().addBitmapToMemoryCache(uri, bitmap);
            iconBitmap = bitmap;
            update();
            Log.v(TAG, "Finished Loading Bitmap from drawable: " + uri);
            return;
        }
    }

    public MarkerOptions getMarkerOptions() {
        if (markerOptions == null) {
            markerOptions = createMarkerOptions();
        }
        return markerOptions;
    }

    @Override
    public void addView(View child, int index) {
        super.addView(child, index);
        // if children are added, it means we are rendering a custom marker
        if (!(child instanceof AirMapCallout)) {
            hasCustomMarkerView = true;
        }
        update();
    }

    @Override
    public Object getFeature() {
        return marker;
    }

    public void setFeature(Marker marker, ClusterManager<AirMapMarker> clusterManager) {
        this.marker = marker;
        this.mClusterManager = clusterManager;
    }

    @Override
    public void addToMap(GoogleMap map) {
        marker = map.addMarker(getMarkerOptions());
    }

    @Override
    public void removeFromMap(GoogleMap map) {
        marker.remove();
        marker = null;
    }

    public BitmapDescriptor getIcon() {
        if (hasCustomMarkerView) {
            // creating a bitmap from an arbitrary view
            if (iconBitmapDescriptor != null) {
                Bitmap viewBitmap = createDrawable();
                int width = Math.max(iconBitmap.getWidth(), viewBitmap.getWidth());
                int height = Math.max(iconBitmap.getHeight(), viewBitmap.getHeight());
                Bitmap combinedBitmap = Bitmap.createBitmap(width, height, iconBitmap.getConfig());
                Canvas canvas = new Canvas(combinedBitmap);
                canvas.drawBitmap(iconBitmap, 0, 0, null);
                canvas.drawBitmap(viewBitmap, 0, 0, null);
                return BitmapDescriptorFactory.fromBitmap(combinedBitmap);
            } else {
                return BitmapDescriptorFactory.fromBitmap(createDrawable());
            }
        } else if (iconBitmapDescriptor != null) {
            // use local image as a marker
            return iconBitmapDescriptor;
        } else {
            // render the default marker pin
            return BitmapDescriptorFactory.defaultMarker(this.markerHue);
        }
    }

    public Bitmap getBitmapIcon() {
        return this.iconBitmap;
    }

    private MarkerOptions createMarkerOptions() {
        MarkerOptions options = new MarkerOptions().position(position);
        if (anchorIsSet) options.anchor(anchorX, anchorY);
        if (calloutAnchorIsSet) options.infoWindowAnchor(calloutAnchorX, calloutAnchorY);
        options.title(title);
        options.snippet(snippet);
        options.rotation(rotation);
        options.flat(flat);
        options.draggable(draggable);
        options.zIndex(zIndex);
        options.alpha(opacity);
        options.icon(getIcon());
        return options;
    }

    public void update() {
        if (marker == null) {
            return;
        }

        Handler mainHandler = new Handler(context.getMainLooper());

        Runnable myRunnable = new Runnable() {
            @Override
            public void run() {
                // runnables are handled by a looper, similar to JS, so this isn't guaranteed to exist at the time of the call.
                if (marker == null) { return; }

                marker.setIcon(getIcon());

                if (anchorIsSet) {
                    marker.setAnchor(anchorX, anchorY);
                } else {
                    marker.setAnchor(0.5f, 1.0f);
                }

                if (calloutAnchorIsSet) {
                    marker.setInfoWindowAnchor(calloutAnchorX, calloutAnchorY);
                } else {
                    marker.setInfoWindowAnchor(0.5f, 0);
                }

                if(cluster && mClusterManager != null) {
                    mClusterManager.cluster();
                }
            }
        };
        mainHandler.post(myRunnable);
    }

    public void update(int width, int height) {
        this.width = width;
        this.height = height;
        update();
    }

    public Bitmap createDrawable() {
        int width = this.width <= 0 ? 100 : this.width;
        int height = this.height <= 0 ? 100 : this.height;
        this.buildDrawingCache();
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(bitmap);
        this.draw(canvas);

        return bitmap;
    }

    public void setCalloutView(AirMapCallout view) {
        this.calloutView = view;
    }

    public AirMapCallout getCalloutView() {
        return this.calloutView;
    }

    public View getCallout() {
        if (this.calloutView == null) return null;

        if (this.wrappedCalloutView == null) {
            this.wrapCalloutView();
        }

        if (this.calloutView.getTooltip()) {
            return this.wrappedCalloutView;
        } else {
            return null;
        }
    }

    public View getInfoContents() {
        if (this.calloutView == null) return null;

        if (this.wrappedCalloutView == null) {
            this.wrapCalloutView();
        }

        if (this.calloutView.getTooltip()) {
            return null;
        } else {
            return this.wrappedCalloutView;
        }
    }

    private void wrapCalloutView() {
        // some hackery is needed to get the arbitrary infowindow view to render centered, and
        // with only the width/height that it needs.
        if (this.calloutView == null || this.calloutView.getChildCount() == 0) {
            return;
        }

        LinearLayout LL = new LinearLayout(context);
        LL.setOrientation(LinearLayout.VERTICAL);
        LL.setLayoutParams(new LinearLayout.LayoutParams(
                this.calloutView.width,
                this.calloutView.height,
                0f
        ));


        LinearLayout LL2 = new LinearLayout(context);
        LL2.setOrientation(LinearLayout.HORIZONTAL);
        LL2.setLayoutParams(new LinearLayout.LayoutParams(
                this.calloutView.width,
                this.calloutView.height,
                0f
        ));

        LL.addView(LL2);
        LL2.addView(this.calloutView);

        this.wrappedCalloutView = LL;
    }

    private int getDrawableResourceByName(String name) {
        return getResources().getIdentifier(
                name,
                "drawable",
                getContext().getPackageName());
    }

    private BitmapDescriptor getBitmapDescriptorByName(String name) {
        return BitmapDescriptorFactory.fromResource(getDrawableResourceByName(name));
    }

    private Bitmap getBitmapByDrawableName(String name) {
        int resourceId = getDrawableResourceByName(name);
        return BitmapFactory.decodeResource(getResources(), resourceId);
    }

    @Override
    public LatLng getPosition() {
        return position;
    }

    @Override
    public String getTitle() {
        return title;
    }

    @Override
    public String getSnippet() {
        return snippet;
    }
}
