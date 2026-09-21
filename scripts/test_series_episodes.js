const assert = require('assert');

// Realistic Xtream get_series_info response
const sampleSeriesInfoPayload = {
    "seasons": [
        {
            "air_date": "2022-04-14",
            "episode_count": 8,
            "id": 1,
            "name": "1. Sezon",
            "overview": "İlk sezon olayları.",
            "season_number": 1,
            "cover": "https://img.sample.org/s1.jpg"
        },
        {
            "air_date": "2023-05-20",
            "episode_count": 10,
            "id": 2,
            "name": "2. Sezon",
            "overview": "İkinci sezon olayları.",
            "season_number": 2,
            "cover": "https://img.sample.org/s2.jpg"
        }
    ],
    "info": {
        "name": "Karanlık Vadi",
        "cover": "https://img.sample.org/kv.jpg",
        "plot": "Soluk kesici bir gerilim dizisi.",
        "cast": "Ahmet K., Mehmet Y.",
        "director": "Ali D.",
        "genre": "Polisiye, Aksiyon",
        "releaseDate": "2022-04-14",
        "rating": "8.7"
    },
    "episodes": {
        "1": [
            {
                "id": "50101",
                "episode_num": 1,
                "title": "Büyük İpucu",
                "container_extension": "mkv",
                "info": {
                    "duration_secs": 3120,
                    "duration": "00:52:00",
                    "plot": "Cinayet mahalli incelenir.",
                    "movie_image": "https://img.sample.org/ep1.jpg",
                    "rating": 8.5
                },
                "season": 1
            },
            {
                "id": "50102",
                "episode_num": 2,
                "title": "Karanlıkta Takip",
                "container_extension": "mp4",
                "info": {
                    "duration_secs": 2880,
                    "duration": "00:48:00",
                    "plot": "Şüpheli kaçmaya çalışır.",
                    "movie_image": "https://img.sample.org/ep2.jpg",
                    "rating": 8.9
                },
                "season": 1
            }
        ],
        "2": [
            {
                "id": 50201, // Note: Int ID to test resilience
                "episode_num": "1", // Note: String episode_num
                "title": "Yeni Düşman",
                "container_extension": "mp4",
                "info": {
                    "duration_secs": 3300,
                    "duration": "00:55:00",
                    "plot": "Yeni bir tehdit ortaya çıkar.",
                    "movie_image": "https://img.sample.org/ep201.jpg"
                },
                "season": 2
            }
        ]
    }
};

function parseSeriesDetails(payload, server, username, password, series) {
    const cleanBase = server.replace(/\/+$/, '');
    const seasonNames = {};
    if (payload.seasons && Array.isArray(payload.seasons)) {
        for (const s of payload.seasons) {
            seasonNames[s.season_number] = s.name;
        }
    }

    const seasonsDict = {};
    if (payload.episodes && typeof payload.episodes === 'object') {
        for (const [seasonKey, epList] of Object.entries(payload.episodes)) {
            const sNum = parseInt(seasonKey, 10) || 1;
            const vodEpisodes = [];

            for (const ep of epList) {
                const epId = String(ep.id);
                const ext = ep.container_extension || 'mp4';
                const streamUrl = `${cleanBase}/series/${username}/${password}/${epId}.${ext}`;
                const epNum = parseInt(ep.episode_num, 10) || 1;
                const dur = ep.info?.duration_secs || 0;
                const minutes = Math.floor(dur / 60);

                vodEpisodes.push({
                    id: `ep_${epId}`,
                    title: ep.title || `${epNum}. Bölüm`,
                    streamURL: streamUrl,
                    duration: dur,
                    formattedDuration: `${minutes} dk`,
                    seriesId: series.id,
                    seasonNumber: sNum,
                    episodeNumber: epNum,
                    posterURL: ep.info?.movie_image || series.coverURL,
                    plot: ep.info?.plot || series.plot,
                    type: 'seriesEpisode'
                });
            }

            vodEpisodes.sort((a, b) => (a.episodeNumber || 0) - (b.episodeNumber || 0));
            seasonsDict[sNum] = vodEpisodes;
        }
    }

    const resultSeasons = [];
    const sortedSeasonNums = Object.keys(seasonsDict).map(Number).sort((a, b) => a - b);
    for (const sNum of sortedSeasonNums) {
        resultSeasons.push({
            seasonNumber: sNum,
            name: seasonNames[sNum] || `${sNum}. Sezon`,
            episodes: seasonsDict[sNum] || []
        });
    }

    return {
        ...series,
        seasons: resultSeasons
    };
}

console.log('Testing Series & Episode Parsing Engine...');

const mockSeries = {
    id: 'series_1234',
    title: 'Karanlık Vadi',
    coverURL: 'https://img.sample.org/kv.jpg',
    categoryName: 'Diziler',
    seasons: []
};

const result = parseSeriesDetails(
    sampleSeriesInfoPayload,
    'http://iptv.server.org:8080',
    'testuser',
    'testpass',
    mockSeries
);

assert.strictEqual(result.seasons.length, 2, 'Expected 2 seasons');
assert.strictEqual(result.seasons[0].name, '1. Sezon');
assert.strictEqual(result.seasons[0].episodes.length, 2, 'Expected 2 episodes in season 1');
assert.strictEqual(result.seasons[1].episodes.length, 1, 'Expected 1 episode in season 2');

const ep1 = result.seasons[0].episodes[0];
assert.strictEqual(ep1.id, 'ep_50101');
assert.strictEqual(ep1.title, 'Büyük İpucu');
assert.strictEqual(ep1.streamURL, 'http://iptv.server.org:8080/series/testuser/testpass/50101.mkv');
assert.strictEqual(ep1.duration, 3120);
assert.strictEqual(ep1.formattedDuration, '52 dk');

const ep201 = result.seasons[1].episodes[0];
assert.strictEqual(ep201.id, 'ep_50201', 'Handled numeric ID properly');
assert.strictEqual(ep201.episodeNumber, 1, 'Handled string episode_num properly');
assert.strictEqual(ep201.streamURL, 'http://iptv.server.org:8080/series/testuser/testpass/50201.mp4');

console.log('ALL SERIES & EPISODE TESTS PASSED SUCCESSFULLY!');
