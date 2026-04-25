{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function onEntrypointLoaded(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      // Avoid fetching fallback fonts from fonts.gstatic.com on restricted networks.
      fontFallbackBaseUrl: '',
    });
    await appRunner.runApp();
  },
});
