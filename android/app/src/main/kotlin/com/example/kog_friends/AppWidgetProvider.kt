package com.example.kog_friends

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val title = widgetData.getString("title", "DDNet Friends")
                val message = widgetData.getString("message", "Sin datos")
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_message, message)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
