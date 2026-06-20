package com.example.birikimly

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BirikimlyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val netAmount = widgetData.getString("net_amount", "₺0,00")
                val incomeAmount = widgetData.getString("income_amount", "₺0,00")
                val expenseAmount = widgetData.getString("expense_amount", "₺0,00")
                val limitAmount = widgetData.getString("limit_amount", "")
                val themeHex = widgetData.getString("theme_hex", null)

                setTextViewText(R.id.tv_net, netAmount)
                setTextViewText(R.id.tv_income, incomeAmount)
                setTextViewText(R.id.tv_expense, expenseAmount)
                
                if (limitAmount.isNullOrEmpty()) {
                    setTextViewText(R.id.tv_limit, "")
                } else {
                    setTextViewText(R.id.tv_limit, "Aylık Limit: $limitAmount")
                }

                if (themeHex != null) {
                    try {
                        val colorInt = android.graphics.Color.parseColor(themeHex)
                        // Apply dynamic theme color to the background image
                        setInt(R.id.iv_background, "setColorFilter", colorInt)
                    } catch (e: Exception) {
                        // ignore parse errors
                    }
                }

                // Expense Intent
                val expenseIntent = Intent(context, MainActivity::class.java).apply {
                    action = "es.antonborri.home_widget.action.LAUNCH"
                    data = Uri.parse("birikimly://add_expense")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val expensePendingIntent = PendingIntent.getActivity(
                    context, 0, expenseIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_add_expense, expensePendingIntent)

                // Income Intent
                val incomeIntent = Intent(context, MainActivity::class.java).apply {
                    action = "es.antonborri.home_widget.action.LAUNCH"
                    data = Uri.parse("birikimly://add_income")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val incomePendingIntent = PendingIntent.getActivity(
                    context, 1, incomeIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_add_income, incomePendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
