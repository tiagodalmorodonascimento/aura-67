package com.aura67.app;

import android.graphics.Color;
import android.os.Bundle;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyFixedSystemBars();
    }

    @Override
    public void onResume() {
        super.onResume();
        applyFixedSystemBars();
    }

    private void applyFixedSystemBars() {
        getWindow().setStatusBarColor(Color.rgb(15, 18, 24));
        getWindow().setNavigationBarColor(Color.rgb(15, 18, 24));
        WindowCompat.setDecorFitsSystemWindows(getWindow(), true);
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.setAppearanceLightStatusBars(false);
        controller.setAppearanceLightNavigationBars(false);
    }
}
