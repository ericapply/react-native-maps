package com.airbnb.android.react.maps;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;

public class LatLngBoundsUtils {

    public static float dist(float lat1, float lng1, float lat2, float lng2) {
        double earthRadius = 6371000; //meters
        double dLat = Math.toRadians(lat2-lat1);
        double dLng = Math.toRadians(lng2-lng1);
        double a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                        Math.sin(dLng/2) * Math.sin(dLng/2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        float dist = (float) (earthRadius * c);

        return dist;
    }

    public static boolean BoundsAreDifferent(LatLngBounds a, LatLngBounds b) {
        LatLng centerA = a.getCenter();
        double latA = centerA.latitude;
        double lngA = centerA.longitude;
        double latDeltaA = a.northeast.latitude - a.southwest.latitude;
        double lngDeltaA = a.northeast.longitude - a.southwest.longitude;

        LatLng centerB = b.getCenter();
        double latB = centerB.latitude;
        double lngB = centerB.longitude;
        double latDeltaB = b.northeast.latitude - b.southwest.latitude;
        double lngDeltaB = b.northeast.longitude - b.southwest.longitude;

        double latEps = LatitudeEpsilon(a, b);
        double lngEps = LongitudeEpsilon(a, b);

        return
                different(latA, latB, latEps) ||
                        different(lngA, lngB, lngEps) ||
                        different(latDeltaA, latDeltaB, latEps) ||
                        different(lngDeltaA, lngDeltaB, lngEps);
    }

    private static boolean different(double a, double b, double epsilon) {
        return Math.abs(a - b) > epsilon;
    }

    private static double LatitudeEpsilon(LatLngBounds a, LatLngBounds b) {
        double sizeA = a.northeast.latitude - a.southwest.latitude; // something mod 180?
        double sizeB = b.northeast.latitude - b.southwest.latitude; // something mod 180?
        double size = Math.min(Math.abs(sizeA), Math.abs(sizeB));
        return size / 2560;
    }

    private static double LongitudeEpsilon(LatLngBounds a, LatLngBounds b) {
        double sizeA = a.northeast.longitude - a.southwest.longitude;
        double sizeB = b.northeast.longitude - b.southwest.longitude;
        double size = Math.min(Math.abs(sizeA), Math.abs(sizeB));
        return size / 2560;
    }
}
